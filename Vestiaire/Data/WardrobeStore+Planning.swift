import Foundation

/// Agenda (événements et tenues planifiées), valises de voyage et liste d'envies.
/// Tout reste en mémoire, dans l'app : rien n'est envoyé à un service distant.
extension WardrobeStore {
    // MARK: - Événements

    func event(id: UUID) -> WardrobeEvent? {
        events.first { $0.id == id }
    }

    /// Les événements qui couvrent ce jour.
    func events(on day: Date) -> [WardrobeEvent] {
        events.filter { $0.contains(day) }.sorted { $0.start < $1.start }
    }

    func upcomingEvents(now: Date = .now) -> [WardrobeEvent] {
        let today = Calendar.current.startOfDay(for: now)
        return events.filter { $0.end >= today }.sorted { $0.start < $1.start }
    }

    func pastEvents(now: Date = .now) -> [WardrobeEvent] {
        let today = Calendar.current.startOfDay(for: now)
        return events.filter { $0.end < today }.sorted { $0.start > $1.start }
    }

    func save(_ event: WardrobeEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }

    /// Supprimer un événement garde ses tenues planifiées (détachées) mais supprime sa valise.
    func deleteEvent(_ event: WardrobeEvent) {
        events.removeAll { $0.id == event.id }
        for index in plans.indices where plans[index].eventID == event.id {
            plans[index].eventID = nil
        }
        packingLists.removeAll { $0.eventID == event.id }
    }

    // MARK: - Tenues planifiées

    func plans(on day: Date) -> [PlannedOutfit] {
        plans.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func upcomingPlans(now: Date = .now) -> [PlannedOutfit] {
        let today = Calendar.current.startOfDay(for: now)
        return plans.filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    @discardableResult
    func plan(itemIDs: [UUID], on date: Date, outfitID: UUID? = nil, eventID: UUID? = nil) -> PlannedOutfit {
        let plan = PlannedOutfit(date: Calendar.current.startOfDay(for: date), itemIDs: itemIDs, outfitID: outfitID, eventID: eventID)
        plans.append(plan)
        return plan
    }

    func update(_ plan: PlannedOutfit) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index] = plan
    }

    func deletePlan(_ plan: PlannedOutfit) {
        plans.removeAll { $0.id == plan.id }
    }

    /// Une tenue planifiée devient une tenue portée seulement quand l'utilisateur le confirme.
    func markWorn(_ plan: PlannedOutfit, context: SessionContext, photo: Data? = nil) {
        let session = logOutfit(date: plan.date, context: context, itemIDs: plan.itemIDs, photo: photo, outfitID: plan.outfitID)
        var updated = plan
        updated.wornSessionID = session.id
        update(updated)
    }

    // MARK: - Valise

    /// Les tenues planifiées pendant un événement (rattachées à lui ou tombant sur ses dates).
    func plans(for event: WardrobeEvent) -> [PlannedOutfit] {
        plans.filter { $0.eventID == event.id || event.contains($0.date) }.sorted { $0.date < $1.date }
    }

    /// Les jours du voyage sans aucune tenue planifiée.
    func daysWithoutOutfit(in event: WardrobeEvent) -> [Date] {
        let planned = plans(for: event)
        return event.days().filter { day in !planned.contains { Calendar.current.isDate($0.date, inSameDayAs: day) } }
    }

    /// Les pièces nécessaires aux tenues du voyage, sans doublon, dans l'ordre des jours.
    func requiredItems(for event: WardrobeEvent) -> [Item] {
        var seen = Set<UUID>()
        return plans(for: event)
            .flatMap(\.itemIDs)
            .filter { seen.insert($0).inserted }
            .compactMap { item(id: $0) }
    }

    enum MissingPiece: Hashable {
        /// Une pièce archivée, vendue ou donnée depuis que la tenue a été planifiée.
        case notActive(Item)
        /// Une pièce essayée virtuellement, que l'utilisateur n'a pas encore.
        case notOwned(TryOnPiece)
    }

    /// Ce qui manque au dressing pour les tenues du voyage. Rien n'est ajouté automatiquement à la valise.
    func missingPieces(for event: WardrobeEvent) -> [MissingPiece] {
        let inactive = requiredItems(for: event)
            .filter { $0.status != .active }
            .map(MissingPiece.notActive)
        var seen = Set<String>()
        let notOwned = plans(for: event)
            .compactMap { plan in plan.outfitID.flatMap { generatedOutfit(id: $0) }?.tryOn }
            .filter { seen.insert($0.description).inserted }
            .map(MissingPiece.notOwned)
        return inactive + notOwned
    }

    func packingList(for event: WardrobeEvent) -> PackingList {
        packingLists.first { $0.eventID == event.id } ?? PackingList(eventID: event.id)
    }

    private func editPackingList(for event: WardrobeEvent, _ change: (inout PackingList) -> Void) {
        var list = packingList(for: event)
        change(&list)
        if let index = packingLists.firstIndex(where: { $0.eventID == event.id }) {
            packingLists[index] = list
        } else {
            packingLists.append(list)
        }
    }

    func togglePacked(_ item: Item, for event: WardrobeEvent) {
        editPackingList(for: event) { list in
            if list.packedItemIDs.contains(item.id) {
                list.packedItemIDs.remove(item.id)
            } else {
                list.packedItemIDs.insert(item.id)
            }
        }
    }

    func addExtra(_ name: String, to event: WardrobeEvent) {
        editPackingList(for: event) { $0.extras.append(PackingExtra(name: name)) }
    }

    func toggleExtra(_ extra: PackingExtra, for event: WardrobeEvent) {
        editPackingList(for: event) { list in
            guard let index = list.extras.firstIndex(where: { $0.id == extra.id }) else { return }
            list.extras[index].isPacked.toggle()
        }
    }

    func removeExtra(_ extra: PackingExtra, from event: WardrobeEvent) {
        editPackingList(for: event) { $0.extras.removeAll { $0.id == extra.id } }
    }

    // MARK: - Liste d'envies

    var consideredWishes: [Wish] {
        wishes.filter { !$0.isPurchased }.sorted { $0.addedAt > $1.addedAt }
    }

    var purchasedWishes: [Wish] {
        wishes.filter(\.isPurchased).sorted { $0.addedAt > $1.addedAt }
    }

    func wish(id: UUID) -> Wish? {
        wishes.first { $0.id == id }
    }

    /// Ajoute un article à la liste d'envies et le relie aux pièces semblables déjà possédées.
    @discardableResult
    func addWish(_ wish: Wish) -> Wish {
        var added = wish
        added.similarItemIDs = similarItems(to: wish.item).map(\.id)
        wishes.append(added)
        return added
    }

    func update(_ wish: Wish) {
        guard let index = wishes.firstIndex(where: { $0.id == wish.id }) else { return }
        var updated = wish
        updated.similarItemIDs = similarItems(to: wish.item).map(\.id)
        wishes[index] = updated
    }

    func removeWish(_ wish: Wish) {
        wishes.removeAll { $0.id == wish.id }
    }

    /// L'article est acheté : il entre dans le dressing, avec le prix estimé comme prix payé.
    @discardableResult
    func markPurchased(_ wish: Wish) -> Item? {
        guard let index = wishes.firstIndex(where: { $0.id == wish.id }), !wishes[index].isPurchased else { return nil }
        let item = wish.item
        items.append(item)
        wishes[index].purchasedItemID = item.id
        return item
    }
}

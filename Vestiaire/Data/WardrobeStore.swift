import Foundation
import Observation

/// Source de vérité de l'app. Pour l'instant remplie avec des données d'exemple et gardée en mémoire :
/// rien n'est sauvegardé d'un lancement à l'autre. Plus tard, elle sera synchronisée avec Supabase,
/// alimenté par le pipeline IA.
@Observable
final class WardrobeStore {
    var user: User
    var friends: [User]
    var items: [Item]
    /// Le journal privé des tenues portées : retrouvées dans la galerie ou enregistrées à la main.
    var sessions: [Session]
    var wearEvents: [WearEvent]
    var generatedOutfits: [GeneratedOutfit]
    var tags: [ItemTag]
    var events: [WardrobeEvent]
    var plans: [PlannedOutfit]
    var packingLists: [PackingList]
    var wishes: [Wish]
    var profiles: [DiscoverProfile]
    var trending: [TrendingOutfit]
    var listings: [Listing]
    var recommendations: [Recommendation]
    /// Profils privés à qui on a envoyé une demande d'ami.
    var friendRequests: Set<UUID> = []
    /// Offres envoyées, par annonce.
    var offers: [UUID: OfferKind] = [:]

    init(
        user: User,
        friends: [User] = [],
        items: [Item] = [],
        sessions: [Session] = [],
        wearEvents: [WearEvent] = [],
        generatedOutfits: [GeneratedOutfit] = [],
        tags: [ItemTag] = [],
        events: [WardrobeEvent] = [],
        plans: [PlannedOutfit] = [],
        packingLists: [PackingList] = [],
        wishes: [Wish] = [],
        profiles: [DiscoverProfile] = [],
        trending: [TrendingOutfit] = [],
        listings: [Listing] = [],
        recommendations: [Recommendation] = []
    ) {
        self.user = user
        self.friends = friends
        self.items = items
        self.sessions = sessions
        self.wearEvents = wearEvents
        self.generatedOutfits = generatedOutfits
        self.tags = tags
        self.events = events
        self.plans = plans
        self.packingLists = packingLists
        self.wishes = wishes
        self.profiles = profiles
        self.trending = trending
        self.listings = listings
        self.recommendations = recommendations
    }

    private var calendar: Calendar { .current }

    var activeItems: [Item] {
        items.filter { $0.status == .active }
    }

    var archivedItems: [Item] {
        items.filter { $0.status == .archived }
    }

    func item(id: UUID) -> Item? {
        items.first { $0.id == id }
    }

    var inviteURL: URL {
        URL(string: "https://vestiaire.app/invite/\(user.id.uuidString)") ?? URL(string: "https://vestiaire.app")!
    }

    // MARK: - Ports

    /// Nombre de jours avec au moins une tenue portée dans le journal.
    func loggedDays(since start: Date? = nil) -> Int {
        Set(sessions
            .filter { session in start.map { session.date >= $0 } ?? true }
            .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    /// Nombre de jours où la pièce est portée.
    func wearCount(of item: Item, since start: Date? = nil) -> Int {
        Set(wearEvents
            .filter { event in event.itemID == item.id && (start.map { event.date >= $0 } ?? true) }
            .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    /// Règle du brief : jours portés ÷ jours enregistrés dans le journal.
    func wearRate(of item: Item, since start: Date? = nil) -> Double {
        let days = loggedDays(since: start)
        guard days > 0 else { return 0 }
        return Double(wearCount(of: item, since: start)) / Double(days)
    }

    func lastWorn(_ item: Item) -> Date? {
        wearEvents.filter { $0.itemID == item.id }.map(\.date).max()
    }

    func costPerWear(of item: Item) -> Double? {
        let wears = wearCount(of: item)
        guard let paid = item.pricePaid, wears > 0 else { return nil }
        return paid / Double(wears)
    }

    /// Une pièce dort si elle n'a pas été portée depuis 90 jours.
    func isDormant(_ item: Item, now: Date = .now) -> Bool {
        guard let last = lastWorn(item) else { return true }
        let limit = calendar.date(byAdding: .day, value: -90, to: now) ?? .distantPast
        return last < limit
    }

    // MARK: - Portefeuille

    var totalPaid: Double {
        activeItems.compactMap(\.pricePaid).reduce(0, +)
    }

    var totalResaleValue: Double {
        activeItems.compactMap(\.resaleValue).reduce(0, +)
    }

    // MARK: - Statistiques et Wrapped

    /// Toutes les statistiques d'une période, calculées à la volée à partir du journal.
    func stats(for period: StatsPeriod, now: Date = .now) -> WardrobeStats {
        let start = period.startDate(now: now)
        let activeIDs = Set(activeItems.map(\.id))
        let periodSessions = sessions.filter { session in start.map { session.date >= $0 } ?? true }

        var wearDaysByItem: [UUID: Set<Date>] = [:]
        for event in wearEvents where activeIDs.contains(event.itemID) {
            if let start, event.date < start { continue }
            wearDaysByItem[event.itemID, default: []].insert(calendar.startOfDay(for: event.date))
        }

        // À égalité, on privilégie les pièces qui ont une vraie photo produit, puis l'ordre du vestiaire.
        let ranked = activeItems
            .compactMap { item in wearDaysByItem[item.id].map { (item: item, wears: $0.count) } }
            .sorted { lhs, rhs in
                if lhs.wears != rhs.wears { return lhs.wears > rhs.wears }
                return lhs.item.productImageName != nil && rhs.item.productImageName == nil
            }

        let rarelyWorn = activeItems
            .map { (item: $0, wears: wearDaysByItem[$0.id]?.count ?? 0) }
            .filter { $0.wears <= 1 }
            .sorted { $0.wears < $1.wears }

        var colorTally: [String: (count: Int, hex: String)] = [:]
        for (id, days) in wearDaysByItem {
            guard let worn = item(id: id), let name = worn.colors.first else { continue }
            colorTally[name, default: (count: 0, hex: worn.colorHex)].count += days.count
        }
        let colors = colorTally
            .map { (name: $0.key, hex: $0.value.hex, wears: $0.value.count) }
            .sorted { $0.wears > $1.wears }

        let costs = activeItems
            .compactMap { item in costPerWear(of: item).map { (item: item, costPerWear: $0) } }
            .sorted { $0.costPerWear < $1.costPerWear }

        let itemCount = activeItems.count
        return WardrobeStats(
            period: period,
            itemCount: itemCount,
            loggedDays: loggedDays(since: start),
            loggedOutfits: periodSessions.count,
            favorite: ranked.first,
            topColor: colors.first.map { (name: $0.name, hex: $0.hex) },
            bestValue: costs.first,
            dormantCount: activeItems.filter { isDormant($0, now: now) }.count,
            wornShare: itemCount > 0 ? Double(wearDaysByItem.count) / Double(itemCount) : 0,
            topItems: Array(ranked.prefix(5)),
            rarelyWorn: rarelyWorn,
            colors: colors,
            costPerWear: costs,
            includesSampleData: periodSessions.contains { $0.isSample }
        )
    }

    /// Nombre de tenues portées enregistrées, découpé selon la période :
    /// par semaine pour le mois, par mois pour l'année, par année depuis le début.
    func outfitCounts(for period: StatsPeriod, now: Date = .now) -> [(label: String, count: Int)] {
        let calendar = Calendar.french
        let french = Locale(identifier: "fr_FR")
        let component: Calendar.Component
        let buckets: [Date]
        switch period {
        case .month:
            component = .weekOfYear
            guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
            var weeks: [Date] = []
            var cursor = calendar.dateInterval(of: .weekOfYear, for: month.start)?.start ?? month.start
            while cursor < month.end {
                weeks.append(cursor)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
                cursor = next
            }
            buckets = weeks
        case .year:
            component = .month
            guard let year = calendar.dateInterval(of: .year, for: now) else { return [] }
            let currentMonth = calendar.component(.month, from: now)
            buckets = (0..<currentMonth).compactMap { calendar.date(byAdding: .month, value: $0, to: year.start) }
        case .all:
            component = .year
            let firstYear = sessions.map { calendar.component(.year, from: $0.date) }.min() ?? calendar.component(.year, from: now)
            let lastYear = calendar.component(.year, from: now)
            buckets = (firstYear...max(firstYear, lastYear)).compactMap { calendar.date(from: DateComponents(year: $0, month: 1, day: 1)) }
        }
        return buckets.map { start in
            let end = calendar.date(byAdding: component, value: 1, to: start) ?? start
            let count = sessions.filter { $0.date >= start && $0.date < end && $0.date <= now }.count
            let label: String
            switch period {
            case .month: label = "Sem. du \(start.formatted(.dateTime.day().month(.abbreviated).locale(french)))"
            case .year: label = start.formatted(.dateTime.month(.abbreviated).locale(french))
            case .all: label = start.formatted(.dateTime.year().locale(french))
            }
            return (label: label, count: count)
        }
    }

    // MARK: - Journal des tenues portées

    /// Les tenues portées, de la plus récente à la plus ancienne.
    var journal: [Session] {
        sessions.sorted { $0.date > $1.date }
    }

    func session(id: UUID) -> Session? {
        sessions.first { $0.id == id }
    }

    /// Les pièces portées lors d'une entrée du journal, y compris celles archivées ou vendues depuis.
    func pieces(in session: Session) -> [Item] {
        var seen = Set<UUID>()
        return wearEvents
            .filter { $0.sessionID == session.id && seen.insert($0.itemID).inserted }
            .compactMap { item(id: $0.itemID) }
    }

    /// Enregistre une tenue portée. C'est la seule façon de créer un port à la main.
    @discardableResult
    func logOutfit(date: Date, context: SessionContext, itemIDs: [UUID], photo: Data? = nil, outfitID: UUID? = nil) -> Session {
        let session = Session(date: date, context: context, origin: .journal, photo: photo, outfitID: outfitID)
        sessions.append(session)
        wearEvents += itemIDs.map { WearEvent(itemID: $0, sessionID: session.id, date: date) }
        return session
    }

    /// Corrige une entrée du journal : date, contexte, photo et pièces portées.
    func updateEntry(_ session: Session, itemIDs: [UUID]) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[index] = session
        wearEvents.removeAll { $0.sessionID == session.id }
        wearEvents += itemIDs.map { WearEvent(itemID: $0, sessionID: session.id, date: session.date) }
    }

    func deleteEntry(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        wearEvents.removeAll { $0.sessionID == session.id }
    }

    /// Combien de fois une tenue proposée a été marquée comme portée.
    func timesWorn(_ outfit: GeneratedOutfit) -> Int {
        sessions.filter { $0.outfitID == outfit.id }.count
    }

    // MARK: - Corrections

    func update(_ item: Item) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    /// « Ce n'est pas à moi » : la pièce et ses ports disparaissent.
    func delete(_ item: Item) {
        items.removeAll { $0.id == item.id }
        wearEvents.removeAll { $0.itemID == item.id }
        for index in plans.indices {
            plans[index].itemIDs.removeAll { $0 == item.id }
        }
        for index in wishes.indices {
            wishes[index].similarItemIDs.removeAll { $0 == item.id }
        }
    }

    /// « Je ne l'ai plus » ou archivage : la pièce sort du dressing actif mais garde son historique.
    func setStatus(_ status: ItemStatus, for item: Item) {
        guard var updated = self.item(id: item.id) else { return }
        updated.status = status
        update(updated)
    }

    func toggleFavorite(_ item: Item) {
        guard var updated = self.item(id: item.id) else { return }
        updated.isFavorite.toggle()
        update(updated)
    }

    /// Fusionne un doublon dans la pièce gardée : ports, photos et infos manquantes.
    func merge(_ duplicate: Item, into kept: Item) {
        guard var target = item(id: kept.id), duplicate.id != kept.id else { return }
        for index in wearEvents.indices where wearEvents[index].itemID == duplicate.id {
            wearEvents[index].itemID = kept.id
        }
        for index in plans.indices {
            plans[index].itemIDs = plans[index].itemIDs.map { $0 == duplicate.id ? kept.id : $0 }
        }
        target.sourcePhotos += duplicate.sourcePhotos
        target.brand = target.brand ?? duplicate.brand
        target.pricePaid = target.pricePaid ?? duplicate.pricePaid
        target.priceNew = target.priceNew ?? duplicate.priceNew
        target.resaleValue = target.resaleValue ?? duplicate.resaleValue
        target.isFavorite = target.isFavorite || duplicate.isFavorite
        target.seasons.formUnion(duplicate.seasons)
        target.occasions.formUnion(duplicate.occasions)
        target.tagIDs.formUnion(duplicate.tagIDs)
        update(target)
        items.removeAll { $0.id == duplicate.id }
    }

    // MARK: - Étiquettes

    func tag(id: UUID) -> ItemTag? {
        tags.first { $0.id == id }
    }

    @discardableResult
    func addTag(named name: String) -> ItemTag {
        let tag = ItemTag(name: name)
        tags.append(tag)
        return tag
    }

    func rename(_ tag: ItemTag, to name: String) {
        guard let index = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tags[index].name = name
    }

    /// Supprimer une étiquette la retire aussi de toutes les pièces.
    func deleteTag(_ tag: ItemTag) {
        tags.removeAll { $0.id == tag.id }
        for index in items.indices {
            items[index].tagIDs.remove(tag.id)
        }
    }

    // MARK: - Archives des tenues

    /// Les tenues proposées encore visibles dans l'historique.
    var visibleGeneratedOutfits: [GeneratedOutfit] {
        generatedOutfits.filter { !$0.isArchived }
    }

    func generatedOutfit(id: UUID) -> GeneratedOutfit? {
        generatedOutfits.first { $0.id == id }
    }

    func setArchived(_ archived: Bool, for outfit: GeneratedOutfit) {
        guard let index = generatedOutfits.firstIndex(where: { $0.id == outfit.id }) else { return }
        generatedOutfits[index].isArchived = archived
    }
}

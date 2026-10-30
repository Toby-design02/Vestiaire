import Foundation
import Observation

/// Source de vérité de l'app. Pour l'instant remplie avec des données d'exemple ;
/// plus tard, elle sera synchronisée avec Supabase, alimenté par le pipeline IA.
@Observable
final class WardrobeStore {
    var user: User
    var friends: [User]
    var items: [Item]
    var sessions: [Session]
    var wearEvents: [WearEvent]
    var outfits: [Outfit]
    var posts: [Post]
    var feed: [FeedPost]
    /// Le moment OOTD du jour : comme sur BeReal, tout le monde a 2 minutes pour poster.
    var ootdMoment: Date
    var generatedOutfits: [GeneratedOutfit]
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
        outfits: [Outfit] = [],
        posts: [Post] = [],
        feed: [FeedPost] = [],
        ootdMoment: Date = .now,
        generatedOutfits: [GeneratedOutfit] = [],
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
        self.outfits = outfits
        self.posts = posts
        self.feed = feed
        self.ootdMoment = ootdMoment
        self.generatedOutfits = generatedOutfits
        self.profiles = profiles
        self.trending = trending
        self.listings = listings
        self.recommendations = recommendations
    }

    private var calendar: Calendar { .current }

    var activeItems: [Item] {
        items.filter { $0.status == .active }
    }

    func item(id: UUID) -> Item? {
        items.first { $0.id == id }
    }

    var inviteURL: URL {
        URL(string: "https://vestiaire.app/invite/\(user.id.uuidString)") ?? URL(string: "https://vestiaire.app")!
    }

    // MARK: - Ports

    /// Nombre de jours où l'utilisateur apparaît sur au moins une photo.
    func photographedDays(since start: Date? = nil) -> Int {
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

    /// Règle du brief : jours portés ÷ jours où l'utilisateur est pris en photo.
    func wearRate(of item: Item, since start: Date? = nil) -> Double {
        let days = photographedDays(since: start)
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

    // MARK: - Wrapped

    func stats(for period: StatsPeriod, now: Date = .now) -> WardrobeStats {
        let start = period.startDate(now: now)
        let activeIDs = Set(activeItems.map(\.id))

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
        let favorite = ranked.first

        var colorTally: [String: (count: Int, hex: String)] = [:]
        for (id, days) in wearDaysByItem {
            guard let worn = item(id: id), let name = worn.colors.first else { continue }
            colorTally[name, default: (count: 0, hex: worn.colorHex)].count += days.count
        }
        let topColor = colorTally
            .max { $0.value.count < $1.value.count }
            .map { (name: $0.key, hex: $0.value.hex) }

        let bestValue = activeItems
            .compactMap { item in costPerWear(of: item).map { (item: item, costPerWear: $0) } }
            .min { $0.costPerWear < $1.costPerWear }

        let itemCount = activeItems.count
        return WardrobeStats(
            period: period,
            itemCount: itemCount,
            photographedDays: photographedDays(since: start),
            favorite: favorite,
            topColor: topColor,
            bestValue: bestValue,
            dormantCount: activeItems.filter { isDormant($0, now: now) }.count,
            wornShare: itemCount > 0 ? Double(wearDaysByItem.count) / Double(itemCount) : 0,
            topItems: Array(ranked.prefix(5))
        )
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
        for index in outfits.indices {
            outfits[index].itemIDs.removeAll { $0 == item.id }
        }
    }

    /// « Je ne l'ai plus » : la pièce sort du vestiaire mais garde son historique.
    func setStatus(_ status: ItemStatus, for item: Item) {
        guard var updated = self.item(id: item.id) else { return }
        updated.status = status
        update(updated)
    }

    /// Fusionne un doublon dans la pièce gardée : ports, photos et infos manquantes.
    func merge(_ duplicate: Item, into kept: Item) {
        guard var target = item(id: kept.id), duplicate.id != kept.id else { return }
        for index in wearEvents.indices where wearEvents[index].itemID == duplicate.id {
            wearEvents[index].itemID = kept.id
        }
        for index in outfits.indices {
            outfits[index].itemIDs = outfits[index].itemIDs.map { $0 == duplicate.id ? kept.id : $0 }
        }
        target.sourcePhotos += duplicate.sourcePhotos
        target.brand = target.brand ?? duplicate.brand
        target.pricePaid = target.pricePaid ?? duplicate.pricePaid
        target.priceNew = target.priceNew ?? duplicate.priceNew
        target.resaleValue = target.resaleValue ?? duplicate.resaleValue
        update(target)
        items.removeAll { $0.id == duplicate.id }
    }
}

import Foundation

/// L'auteur d'un vestiaire à découvrir (créateur, ami d'ami).
struct ProfileAuthor: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var handle: String
    var hex: String
    var followers: Int? = nil
    /// Pour les amis d'amis : l'ami en commun.
    var viaFriend: String? = nil
}

/// Un profil qu'on peut découvrir : vestiaire public, ou privé (demande d'ami).
struct DiscoverProfile: Identifiable, Hashable {
    var author: ProfileAuthor
    var isPublic: Bool
    var style: String
    var pieces: [Item]

    var id: UUID { author.id }
}

/// Une tenue tendance, mise en scène comme celles de l'agent.
struct TrendingOutfit: Identifiable, Hashable {
    var id = UUID()
    var profileID: UUID
    var title: String
    var pieces: [Item]
    var likes: Int
    var backdropHex: String
}

/// Une pièce d'un autre utilisateur ouverte aux offres ou aux échanges.
struct Listing: Identifiable, Hashable {
    var id = UUID()
    var profileID: UUID
    var item: Item
    var price: Double
    var size: String
    var condition: String
}

/// Une pièce à acheter qui compléterait le dressing.
struct Recommendation: Identifiable, Hashable {
    var id = UUID()
    var item: Item
    var price: Double
    var shop: String
    var headline: String
    var reason: String
}

enum OfferKind: Hashable {
    case price(Double)
    case swap(UUID)
}

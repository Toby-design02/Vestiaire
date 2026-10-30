import Foundation

/// Les deux cercles du feed, comme sur BeReal.
enum FeedCircle: String, CaseIterable, Identifiable {
    case friends, discovery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .friends: "Mes amis"
        case .discovery: "Amis d'amis"
        }
    }
}

struct FeedAuthor: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var handle: String
    var hex: String
    var followers: Int? = nil
    /// Pour les amis d'amis : l'ami en commun.
    var viaFriend: String? = nil
    var isMe = false
}

/// Réaction façon RealMoji.
struct Reaction: Identifiable, Hashable {
    var id = UUID()
    var authorName: String
    var hex: String
    var emoji: String
}

/// Un OOTD publié : la tenue à plat (photo principale) et le selfie miroir (vignette).
struct FeedPost: Identifiable, Hashable {
    var id = UUID()
    var author: FeedAuthor
    var circle: FeedCircle
    var date: Date
    var minutesLate = 0
    var place: String? = nil
    var caption: String? = nil
    var pieces: [Item]
    /// Vraie photo de la tenue, si elle existe (sinon : la tenue à plat).
    var photoName: String? = nil
    /// Couleur du sol sur lequel la tenue est posée.
    var backdropHex: String
    var reactions: [Reaction] = []
    var commentCount = 0
    var audience: Audience = .friends
}

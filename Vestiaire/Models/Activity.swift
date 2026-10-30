import Foundation

enum SessionContext: String, CaseIterable, Codable {
    case everyday, work, evening, travel, beach, sport

    var label: String {
        switch self {
        case .everyday: "Quotidien"
        case .work: "Travail"
        case .evening: "Soirée"
        case .travel: "Voyage"
        case .beach: "Plage"
        case .sport: "Sport"
        }
    }
}

/// Une séance photo : les photos prises au même moment, au même endroit.
struct Session: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var place: String? = nil
    var context: SessionContext = .everyday
    var photoCount = 1
}

/// Une pièce portée lors d'une séance. Base du calcul des ports.
struct WearEvent: Identifiable, Hashable, Codable {
    var id = UUID()
    var itemID: UUID
    var sessionID: UUID
    var date: Date
}

enum OutfitSource: String, Codable {
    case photo, ootd, agent
}

struct Outfit: Identifiable, Hashable, Codable {
    var id = UUID()
    var itemIDs: [UUID]
    var date: Date
    var source: OutfitSource
    var flatImageName: String? = nil
}

enum Audience: String, Codable {
    case friends, everyone
}

struct Post: Identifiable, Hashable, Codable {
    var id = UUID()
    var outfitID: UUID
    var authorID: UUID
    var audience: Audience = .friends
    var reactions: [String] = []
}

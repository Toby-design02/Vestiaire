import Foundation

enum SessionContext: String, CaseIterable, Identifiable, Codable {
    case everyday, work, evening, travel, beach, sport

    var id: String { rawValue }

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

    /// Contexte proposé quand on porte une tenue composée pour cette occasion.
    init(_ occasion: Occasion) {
        switch occasion {
        case .work: self = .work
        case .evening: self = .evening
        case .everyday, .weekend: self = .everyday
        }
    }
}

/// D'où vient une tenue portée.
enum SessionOrigin: String, Codable {
    /// Retrouvée par le pipeline IA dans les photos de la galerie.
    case gallery
    /// Enregistrée à la main dans le journal.
    case journal
}

/// Une tenue portée : une entrée du journal privé.
/// Soit retrouvée dans la galerie (les photos prises au même moment, au même endroit),
/// soit enregistrée à la main. Les pièces portées sont les `WearEvent` de la séance.
/// Rien ici n'est publié ni partagé.
struct Session: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var place: String? = nil
    var context: SessionContext = .everyday
    var photoCount = 1
    var origin: SessionOrigin = .gallery
    /// Photo personnelle de la tenue. Elle reste sur l'iPhone.
    var photo: Data? = nil
    /// Photo d'exemple livrée avec l'app (prototype), affichée tant qu'il n'y a pas de photo personnelle.
    var samplePhotoName: String? = nil
    /// La tenue proposée par l'agent dont vient cette entrée, si on l'a marquée comme portée.
    var outfitID: UUID? = nil
    /// Donnée d'exemple du prototype, pas un vrai port.
    var isSample = false
}

/// Une pièce portée lors d'une séance. Base du calcul des ports.
struct WearEvent: Identifiable, Hashable, Codable {
    var id = UUID()
    var itemID: UUID
    var sessionID: UUID
    var date: Date
}

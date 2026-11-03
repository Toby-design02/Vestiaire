import Foundation

enum EventKind: String, CaseIterable, Identifiable, Codable {
    case general, travel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "Événement"
        case .travel: "Voyage"
        }
    }
}

/// Un événement de l'agenda : un mariage, une semaine de séminaire, un voyage…
struct WardrobeEvent: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kind: EventKind = .general
    var start: Date
    var end: Date
    var place: String? = nil
    var isSample = false

    /// Les jours couverts par l'événement, du premier au dernier inclus.
    func days(calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: max(start, end))
        var days: [Date] = []
        var day = first
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: max(start, end))
    }
}

/// Une tenue programmée pour un jour. Elle ne compte comme portée qu'une fois marquée comme portée dans le journal.
struct PlannedOutfit: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var itemIDs: [UUID]
    /// La tenue proposée par l'agent d'où vient ce planning, s'il y en a une.
    var outfitID: UUID? = nil
    /// L'événement (ou le voyage) auquel la tenue est rattachée.
    var eventID: UUID? = nil
    var note: String? = nil
    /// L'entrée du journal créée quand la tenue a été marquée comme portée.
    var wornSessionID: UUID? = nil
    var isSample = false
}

/// Un élément ajouté à la main à la valise (trousse de toilette, chargeur…).
struct PackingExtra: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var isPacked = false
}

/// La valise d'un voyage. Les pièces viennent des tenues planifiées sur le voyage :
/// on ne garde ici que ce qui est coché et ce qui a été ajouté à la main.
struct PackingList: Identifiable, Hashable, Codable {
    var eventID: UUID
    var packedItemIDs: Set<UUID> = []
    var extras: [PackingExtra] = []

    var id: UUID { eventID }
}

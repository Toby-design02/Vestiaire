import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case month, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month: "Ce mois"
        case .year: "Cette année"
        case .all: "Tout"
        }
    }

    func startDate(now: Date = .now) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .month: return calendar.dateInterval(of: .month, for: now)?.start
        case .year: return calendar.dateInterval(of: .year, for: now)?.start
        case .all: return nil
        }
    }

    /// Libellé court pour les cartes story : « octobre », « 2026 »…
    func cardLabel(now: Date = .now) -> String {
        switch self {
        case .month: return now.monthFR
        case .year: return now.formatted(.dateTime.year())
        case .all: return "depuis le début"
        }
    }
}

/// Récap d'une période, calculé à partir du journal des tenues portées.
/// Sert au Wrapped et au tableau de bord des statistiques.
struct WardrobeStats {
    let period: StatsPeriod
    let itemCount: Int
    /// Jours avec au moins une tenue portée enregistrée.
    let loggedDays: Int
    /// Tenues portées enregistrées sur la période.
    let loggedOutfits: Int
    let favorite: (item: Item, wears: Int)?
    let topColor: (name: String, hex: String)?
    let bestValue: (item: Item, costPerWear: Double)?
    let dormantCount: Int
    /// Part de la garde-robe portée au moins une fois sur la période.
    let wornShare: Double
    /// Les pièces les plus portées, de la plus portée à la moins portée.
    var topItems: [(item: Item, wears: Int)] = []
    /// Les pièces actives portées au plus une fois sur la période, de la moins portée à la plus portée.
    var rarelyWorn: [(item: Item, wears: Int)] = []
    /// Les couleurs portées, de la plus portée à la moins portée (en jours de port).
    var colors: [(name: String, hex: String, wears: Int)] = []
    /// Coût par port de chaque pièce active qui a un prix et au moins un port, du moins cher au plus cher.
    var costPerWear: [(item: Item, costPerWear: Double)] = []
    /// Une partie des tenues de la période sont des données d'exemple.
    var includesSampleData = false
}

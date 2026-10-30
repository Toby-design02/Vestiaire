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

/// Récap du Wrapped pour une période.
struct WardrobeStats {
    let period: StatsPeriod
    let itemCount: Int
    let photographedDays: Int
    let favorite: (item: Item, wears: Int)?
    let topColor: (name: String, hex: String)?
    let bestValue: (item: Item, costPerWear: Double)?
    let dormantCount: Int
    /// Part de la garde-robe portée au moins une fois sur la période.
    let wornShare: Double
    /// Les pièces les plus portées, de la plus portée à la moins portée.
    var topItems: [(item: Item, wears: Int)] = []
}

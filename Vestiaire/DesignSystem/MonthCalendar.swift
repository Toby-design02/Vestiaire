import SwiftUI

/// Ce qu'un jour du calendrier affiche sous son numéro.
struct DayMarker {
    /// Une tenue (portée ou planifiée) ce jour-là : carré plein.
    var hasOutfit = false
    /// Un jour à venir sans tenue planifiée : carré vide.
    var isMissingOutfit = false
    /// Un événement couvre ce jour : trait sous le numéro.
    var hasEvent = false
}

/// Calendrier d'un mois, semaines commençant le lundi, dans le style de la boutique :
/// chiffres fins, filets, aucun fond arrondi.
struct MonthCalendar: View {
    @Binding var month: Date
    @Binding var selection: Date
    let marker: (Date) -> DayMarker

    private let calendar = Calendar.french
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: leading) + dates
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shift(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Mois précédent")
                Spacer()
                Text(month.monthYearFR.capitalized)
                    .font(Theme.title(22))
                Spacer()
                Button {
                    shift(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Mois suivant")
            }
            .font(.system(size: 13, weight: .light))
            .foregroundStyle(Theme.ink)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { index in
                    Text(["L", "M", "M", "J", "V", "S", "D"][index])
                        .font(Theme.label)
                        .foregroundStyle(Theme.muted)
                        .frame(height: 24)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 50)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let mark = marker(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)
        return Button {
            selection = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 15, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
                    .frame(width: 32, height: 26)
                    .background(isSelected ? Theme.ink : Color.clear)
                    .overlay(alignment: .bottom) {
                        if mark.hasEvent {
                            Rectangle().fill(isSelected ? Theme.paper : Theme.accent).frame(height: 2)
                        }
                    }
                Group {
                    if mark.hasOutfit {
                        Rectangle().fill(Theme.ink)
                    } else if mark.isMissingOutfit {
                        Rectangle().stroke(Theme.muted, lineWidth: 1)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(day, mark))
    }

    private func accessibilityText(_ day: Date, _ mark: DayMarker) -> String {
        var parts = [day.dayFR]
        if mark.hasOutfit { parts.append("tenue") }
        if mark.isMissingOutfit { parts.append("aucune tenue prévue") }
        if mark.hasEvent { parts.append("événement") }
        return parts.joined(separator: ", ")
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) {
            withAnimation(.snappy) { month = next }
        }
    }
}

/// Légende des marques du calendrier.
struct CalendarLegend: View {
    var showsMissing = true
    var showsEvents = true
    var outfitLabel = "Tenue"

    var body: some View {
        HStack(spacing: 16) {
            entry(outfitLabel) { Rectangle().fill(Theme.ink) }
            if showsMissing {
                entry("Aucune tenue prévue") { Rectangle().stroke(Theme.muted, lineWidth: 1) }
            }
            if showsEvents {
                HStack(spacing: 6) {
                    Rectangle().fill(Theme.accent).frame(width: 12, height: 2)
                    Text("Événement")
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.muted)
    }

    private func entry<Mark: View>(_ label: String, @ViewBuilder mark: () -> Mark) -> some View {
        HStack(spacing: 6) {
            mark().frame(width: 6, height: 6)
            Text(label)
        }
    }
}

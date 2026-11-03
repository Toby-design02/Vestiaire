import Foundation

private let french = Locale(identifier: "fr_FR")

extension Double {
    var euros: String {
        formatted(.currency(code: "EUR").locale(french))
    }

    var percent: String {
        formatted(.percent.precision(.fractionLength(0)).locale(french))
    }
}

extension Date {
    var shortFR: String {
        formatted(.dateTime.day().month(.abbreviated).year().locale(french))
    }

    var monthFR: String {
        formatted(.dateTime.month(.wide).locale(french))
    }

    var monthYearFR: String {
        formatted(.dateTime.month(.wide).year().locale(french))
    }

    /// « mardi 4 novembre »
    var dayFR: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(french))
    }

    /// « 4 nov. »
    var dayMonthFR: String {
        formatted(.dateTime.day().month(.abbreviated).locale(french))
    }

    var timeFR: String {
        formatted(.dateTime.hour().minute().locale(french))
    }

    /// « il y a 2 heures »
    func relativeFR(to now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = french
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: now)
    }
}

extension Calendar {
    /// Calendrier français : les semaines commencent le lundi.
    static var french: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        return calendar
    }
}

/// « du 10 au 12 nov. », ou « 4 nov. » sur un seul jour.
func dateRangeLabel(_ start: Date, _ end: Date) -> String {
    if Calendar.current.isDate(start, inSameDayAs: end) {
        return start.dayMonthFR
    }
    return "du \(start.dayMonthFR) au \(end.dayMonthFR)"
}

func outfitsLabel(_ count: Int) -> String {
    count == 1 ? "1 tenue" : "\(count) tenues"
}

func portsLabel(_ count: Int) -> String {
    count == 1 ? "1 port" : "\(count) ports"
}

/// « 48,2 k abonnés »
func followersLabel(_ count: Int) -> String {
    if count >= 1000 {
        let thousands = (Double(count) / 1000).formatted(.number.precision(.fractionLength(1)).locale(french))
        return "\(thousands) k abonnés"
    }
    return "\(count) abonnés"
}

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

import SwiftUI

/// Couleurs et typographies de l'app.
/// Trois ambiances, une seule identité :
/// - la boutique (vestiaire, fiches, tenues) : blanc, noir, beaucoup d'air, façon e-shop de luxe ;
/// - le feed (OOTD) : nuit, brut, façon BeReal ;
/// - le Wrapped : le format story de Spotify Wrapped, avec les couleurs et les typos de la boutique.
/// La couleur signature, le vermillon, sert aux moments « en direct » (OOTD du jour, alertes).
enum Theme {
    // Boutique
    static let ink = Color(hex: "111111")
    static let paper = Color(hex: "FFFFFF")
    static let card = Color(hex: "F3F2EF")
    static let muted = Color(hex: "77736D")
    static let line = Color(hex: "E4E2DD")
    static let accent = Color(hex: "E5482D")
    static let positive = Color(hex: "2F7A4B")
    static let negative = Color(hex: "B3321F")

    // Feed (nuit)
    static let night = Color(hex: "0B0B0A")
    static let nightRaised = Color(hex: "1B1A18")
    static let bone = Color(hex: "F2EEE6")
    static let nightMuted = Color(hex: "8E8981")

    // Wrapped : le format de Spotify Wrapped, avec les couleurs de l'app.
    enum Wrapped {
        static let ink = "111111"
        static let paper = "FFFFFF"
        static let card = "F3F2EF"
        static let sapin = "2F4A3A"
        static let vermilion = "E5482D"
        static let bone = "F2EEE6"
    }

    /// Titres éditoriaux de la boutique : serif fin, comme les grands e-shops.
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .light, design: .serif)
    }

    /// Gros chiffres du feed (compte à rebours, souvenirs) : sans serif très gras et resserré.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    /// Logo et titres du feed : sans serif gras et large.
    static func wordmark(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }

    static let label = Font.system(size: 11, weight: .semibold)
    static let body = Font.system(size: 15)

    /// Noir ou blanc selon la clarté du fond, pour que le texte reste lisible.
    static func textColor(onHex hex: String) -> Color {
        isLight(hex: hex, threshold: 0.6) ? ink : bone
    }

    static func isLight(hex: String, threshold: Double = 0.8) -> Bool {
        let (r, g, b) = Color.components(hex: hex)
        return 0.299 * r + 0.587 * g + 0.114 * b > threshold
    }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = Color.components(hex: hex)
        self.init(red: r, green: g, blue: b)
    }

    static func components(hex: String) -> (Double, Double, Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}

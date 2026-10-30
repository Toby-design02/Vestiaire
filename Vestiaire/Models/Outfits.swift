import Foundation

/// Occasion demandée à l'agent de tenues.
enum Occasion: String, CaseIterable, Identifiable, Hashable {
    case everyday, work, evening, weekend

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyday: "Quotidien"
        case .work: "Travail"
        case .evening: "Soirée"
        case .weekend: "Week-end"
        }
    }
}

/// Style demandé à l'agent de tenues.
enum StylePreset: String, CaseIterable, Identifiable, Hashable {
    case minimal, street, chic, relaxed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: "Minimal"
        case .street: "Street"
        case .chic: "Chic"
        case .relaxed: "Décontracté"
        }
    }
}

/// Une pièce qu'on n'a pas encore, à essayer virtuellement dans une tenue.
struct TryOnPiece: Hashable {
    var description: String
    var photo: Data? = nil

    /// La pièce telle que l'app la comprend (rayon et couleur lus dans la description).
    var item: Item {
        let parsed = PieceDescription(description)
        var item = Item(category: parsed.category, type: parsed.type, colors: [parsed.colorName], colorHex: parsed.colorHex)
        item.brand = parsed.brand.map { BrandInfo(name: $0, confidence: 1, source: .user) }
        return item
    }
}

/// Paramètres d'une demande à l'agent de tenues.
struct OutfitRequest: Hashable {
    var requiredIDs: Set<UUID> = []
    var useWeather = true
    var occasion: Occasion = .everyday
    var style: StylePreset = .minimal
    var tryOn: TryOnPiece? = nil
}

/// Une tenue proposée par l'agent.
struct GeneratedOutfit: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var itemIDs: [UUID]
    var tryOn: TryOnPiece? = nil
    var occasion: Occasion
    var style: StylePreset
    var weather: String? = nil
    /// Image générée (mise en scène de la tenue). En attendant le pipeline, seule la tenue complète en a une.
    var renderName: String? = nil
    var reasons: [String] = []
}

/// Lit le rayon, le type, la couleur et la marque dans une description libre :
/// « pantalon bleu », « casquette Jacquemus beige »…
struct PieceDescription {
    let category: ClothingCategory
    let type: String
    let colorName: String
    let colorHex: String
    let brand: String?

    private static let categories: [(String, ClothingCategory, String)] = [
        ("casquette", .accessories, "Casquette"), ("bonnet", .accessories, "Bonnet"), ("écharpe", .accessories, "Écharpe"),
        ("ceinture", .accessories, "Ceinture"), ("lunettes", .accessories, "Lunettes"), ("sac", .accessories, "Sac"),
        ("jean", .bottoms, "Jean"), ("pantalon", .bottoms, "Pantalon"), ("short", .bottoms, "Short"), ("jupe", .bottoms, "Jupe"), ("chino", .bottoms, "Chino"),
        ("manteau", .outerwear, "Manteau"), ("veste", .outerwear, "Veste"), ("blouson", .outerwear, "Blouson"), ("doudoune", .outerwear, "Doudoune"), ("trench", .outerwear, "Trench"),
        ("pull", .knitwear, "Pull"), ("cardigan", .knitwear, "Cardigan"), ("sweat", .knitwear, "Sweat"),
        ("t-shirt", .baseLayer, "T-shirt"), ("tee", .baseLayer, "T-shirt"), ("chemise", .baseLayer, "Chemise"), ("polo", .baseLayer, "Polo"),
        ("basket", .shoes, "Baskets"), ("chaussure", .shoes, "Chaussures"), ("mocassin", .shoes, "Mocassins"), ("boots", .shoes, "Boots"), ("bottine", .shoes, "Bottines"), ("derbies", .shoes, "Derbies"),
    ]

    static let colors: [(String, String)] = [
        ("noir", "1C1C1C"), ("blanc", "F4F2EE"), ("écru", "EDE4D3"), ("beige", "C9B99A"), ("camel", "B98A5A"),
        ("marron", "5A3A28"), ("gris", "8E8E8E"), ("marine", "1F2A44"), ("indigo", "2B3A55"), ("bleu", "2E4A7D"),
        ("vert", "2F4A3A"), ("kaki", "5E6044"), ("rouge", "A23B2E"), ("bordeaux", "6B1E2A"), ("rose", "F5A8C6"),
    ]

    private static let brands = ["Jacquemus", "Carhartt", "A.P.C.", "COS", "Arket", "Levi's", "Uniqlo", "Margiela", "Acne", "Nike", "New Balance", "Lemaire", "Our Legacy", "Ami"]

    init(_ text: String) {
        let lower = text.lowercased()
        let match = Self.categories.first { lower.contains($0.0) }
        category = match?.1 ?? .accessories
        type = match?.2 ?? "Pièce"
        let color = Self.colors.first { lower.contains($0.0) }
        colorName = color.map { $0.0.capitalized } ?? "Noir"
        colorHex = color?.1 ?? "1C1C1C"
        brand = Self.brands.first { lower.contains($0.lowercased()) }
    }
}

import Foundation

enum WishSource: String, Codable {
    case fittingRoom, discover, manual

    var label: String {
        switch self {
        case .fittingRoom: "Cabine d'essayage"
        case .discover: "Découvrir"
        case .manual: "Ajout manuel"
        }
    }
}

/// Un vêtement envisagé avant achat. La liste est privée.
/// Aucune information n'est récupérée automatiquement sur le web : l'URL et le prix sont saisis à la main.
struct Wish: Identifiable, Hashable, Codable {
    var id = UUID()
    var description: String
    var category: ClothingCategory
    var colorName: String
    var colorHex: String
    var brand: String? = nil
    var estimatedPrice: Double? = nil
    var url: String? = nil
    var photo: Data? = nil
    var addedAt: Date
    var source: WishSource = .manual
    /// Les pièces du dressing qui ressemblent à cet article, relevées au moment de l'ajout.
    var similarItemIDs: [UUID] = []
    /// Une fois acheté, la pièce créée dans le dressing.
    var purchasedItemID: UUID? = nil
    var isSample = false

    var isPurchased: Bool { purchasedItemID != nil }

    /// Rayon, type et couleur lus dans la description (« pantalon bleu », « casquette Jacquemus beige »…).
    init(description: String, brand: String? = nil, estimatedPrice: Double? = nil, url: String? = nil, photo: Data? = nil, addedAt: Date = .now, source: WishSource = .manual) {
        let parsed = PieceDescription(description)
        self.description = description
        category = parsed.category
        colorName = parsed.colorName
        colorHex = parsed.colorHex
        self.brand = brand ?? parsed.brand
        self.estimatedPrice = estimatedPrice
        self.url = url
        self.photo = photo
        self.addedAt = addedAt
        self.source = source
    }

    /// L'article tel que l'app le dessine et le compare au dressing.
    var item: Item {
        var item = Item(category: category, type: PieceDescription(description).type, colors: [colorName], colorHex: colorHex)
        item.brand = brand.map { BrandInfo(name: $0, confidence: 1, source: .user) }
        item.pricePaid = estimatedPrice
        return item
    }
}

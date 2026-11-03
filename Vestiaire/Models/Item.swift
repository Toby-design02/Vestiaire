import Foundation

/// Rayon du vestiaire.
enum ClothingCategory: String, CaseIterable, Identifiable, Codable {
    case outerwear, knitwear, baseLayer, bottoms, shoes, accessories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .outerwear: "Vestes et manteaux"
        case .knitwear: "Pulls"
        case .baseLayer: "Première couche"
        case .bottoms: "Bas"
        case .shoes: "Chaussures"
        case .accessories: "Accessoires"
        }
    }

    /// Silhouette affichée tant qu'il n'y a pas de photo produit générée.
    var symbol: String {
        switch self {
        case .outerwear: "hanger"
        case .knitwear: "tshirt.fill"
        case .baseLayer: "tshirt"
        case .bottoms: "hanger"
        case .shoes: "shoeprint.fill"
        case .accessories: "eyeglasses"
        }
    }
}

enum BrandSource: String, Codable {
    case photo, web, user
}

struct BrandInfo: Hashable, Codable {
    var name: String
    var model: String? = nil
    var confidence: Double = 1
    var source: BrandSource = .photo
}

/// Statut d'une pièce. Seules les pièces `active` sont dans le dressing et dans les tenues proposées.
/// `archived` : rangée de côté (hors saison, à retoucher…), restaurable, historique de port conservé.
/// `sold` et `donated` : la pièce est sortie du vestiaire.
enum ItemStatus: String, Codable {
    case active, archived, sold, donated
}

enum Season: String, CaseIterable, Identifiable, Codable {
    case spring, summer, autumn, winter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spring: "Printemps"
        case .summer: "Été"
        case .autumn: "Automne"
        case .winter: "Hiver"
        }
    }
}

/// Étiquette personnalisée, créée par l'utilisateur (« Uniforme », « À retoucher »…).
struct ItemTag: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
}

enum PhotoAngle: String, Codable {
    case front, back, side

    var label: String {
        switch self {
        case .front: "Face"
        case .back: "Dos"
        case .side: "Profil"
        }
    }
}

/// Photo d'origine dans la photothèque. Seul l'identifiant est gardé : la photo reste sur l'iPhone.
struct SourcePhoto: Hashable, Codable {
    var angle: PhotoAngle
    var assetIdentifier: String
}

/// Une pièce du vestiaire, telle que le pipeline IA la décrit.
struct Item: Identifiable, Hashable, Codable {
    var id = UUID()
    var category: ClothingCategory
    var type: String
    var colors: [String]
    var colorHex: String
    var pattern: String? = nil
    var material: String? = nil
    var fit: String? = nil
    var collar: String? = nil
    var frontDetails: String? = nil
    var backDetails: String? = nil
    var detectedTexts: [String] = []
    var brand: BrandInfo? = nil
    var pricePaid: Double? = nil
    var priceNew: Double? = nil
    var resaleValue: Double? = nil
    var status: ItemStatus = .active
    var productImageName: String? = nil
    var sourcePhotos: [SourcePhoto] = []
    /// Seconde main : d'autres utilisateurs peuvent faire une offre ou proposer un échange.
    var openToOffers = false
    var openToSwap = false
    var isFavorite = false
    /// Saisons et occasions renseignées par l'utilisateur ; vides tant qu'il ne les a pas indiquées.
    var seasons: Set<Season> = []
    var occasions: Set<Occasion> = []
    var tagIDs: Set<UUID> = []
}

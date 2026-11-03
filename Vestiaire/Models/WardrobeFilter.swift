import Foundation

/// Les filtres du dressing. Dans un même groupe, une pièce doit correspondre à l'un des choix ;
/// entre les groupes, elle doit correspondre à tous.
struct WardrobeFilter: Equatable {
    var categories: Set<ClothingCategory> = []
    var colors: Set<String> = []
    var seasons: Set<Season> = []
    var occasions: Set<Occasion> = []
    var materials: Set<String> = []
    var tagIDs: Set<UUID> = []
    var favoritesOnly = false

    var isEmpty: Bool { self == WardrobeFilter() }

    /// Nombre de choix actifs, hors rayon (déjà visible dans les onglets).
    var activeCount: Int {
        colors.count + seasons.count + occasions.count + materials.count + tagIDs.count + (favoritesOnly ? 1 : 0)
    }

    func matches(_ item: Item) -> Bool {
        if !categories.isEmpty, !categories.contains(item.category) { return false }
        if !colors.isEmpty, colors.isDisjoint(with: item.colors) { return false }
        if !seasons.isEmpty, seasons.isDisjoint(with: item.seasons) { return false }
        if !occasions.isEmpty, occasions.isDisjoint(with: item.occasions) { return false }
        if !materials.isEmpty, !materials.contains(item.material ?? "") { return false }
        if !tagIDs.isEmpty, tagIDs.isDisjoint(with: item.tagIDs) { return false }
        if favoritesOnly, !item.isFavorite { return false }
        return true
    }
}

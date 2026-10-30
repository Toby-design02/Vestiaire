import Foundation

/// Le selfie de référence reste sur l'appareil : il n'apparaît jamais dans ce modèle synchronisé.
struct User: Identifiable, Hashable, Codable {
    var id = UUID()
    var displayName: String
    var isWardrobePublic = false
    var friendIDs: [UUID] = []
}

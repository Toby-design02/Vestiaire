import SwiftUI

/// L'agent de tenues et la cabine d'essayage.
/// Pour l'instant ce sont des règles simples ; plus tard, le pipeline IA prendra le relais
/// (choix des pièces et image générée de la tenue).
extension WardrobeStore {
    static let weatherToday = (label: "Paris · 11 °C, couvert", temperature: 11)

    /// Les quatre photos qui composent la mise en scène d'exemple (photo « outfit-chaise »).
    private static let sampleRenderPieces: Set<String> = ["pull-vert-sapin", "jean-brut", "tabi-noires", "ceinture-noire"]

    func generateOutfit(_ request: OutfitRequest, now: Date = .now) -> GeneratedOutfit {
        var chosen = activeItems.filter { request.requiredIDs.contains($0.id) }
        var reasons: [String] = []
        var filled = Set(chosen.map(\.category))

        if !chosen.isEmpty {
            reasons.append("Tu voulais porter \(chosen.map { $0.type.lowercased() }.joined(separator: " et ")) : la tenue part de là.")
        }
        if let tryOn = request.tryOn {
            let piece = tryOn.item
            filled.insert(piece.category)
            reasons.append("Construite autour de la pièce que tu hésites à acheter : \(tryOn.description).")
        }

        let temperature = Self.weatherToday.temperature
        let cold = request.useWeather && temperature < 15
        if request.useWeather {
            reasons.append(cold ? "\(temperature) °C et couvert : on garde de la laine." : "\(temperature) °C : on reste léger.")
        }

        // Un seul haut, choisi selon la météo ; puis le bas, les chaussures, et un accessoire si le style s'y prête.
        let tops: [ClothingCategory] = cold ? [.knitwear, .baseLayer, .outerwear] : [.baseLayer, .knitwear, .outerwear]
        let hasTop = filled.contains { tops.contains($0) }
        var slots: [ClothingCategory] = []
        if !hasTop, let top = tops.first(where: { category in activeItems.contains { $0.category == category } }) {
            slots.append(top)
        }
        if cold, temperature < 8, !filled.contains(.outerwear) { slots.append(.outerwear) }
        slots += [.bottoms, .shoes]
        if request.style != .relaxed { slots.append(.accessories) }

        for slot in slots where !filled.contains(slot) {
            let candidates = activeItems.filter { $0.category == slot }
            // Rotation : on privilégie la pièce portée il y a le plus longtemps.
            guard let pick = candidates.min(by: { (lastWorn($0) ?? .distantPast) < (lastWorn($1) ?? .distantPast) }) else { continue }
            chosen.append(pick)
            filled.insert(slot)
            if let last = lastWorn(pick) {
                let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
                if days >= 5 {
                    reasons.append("\(pick.type) : pas porté depuis \(days) jours, c'est son tour.")
                }
            }
        }

        reasons.append(styleNote(request))

        let imageNames = Set(chosen.compactMap(\.productImageName))
        let isSampleRender = request.tryOn == nil && imageNames == Self.sampleRenderPieces && chosen.count == 4
        return GeneratedOutfit(
            date: now,
            itemIDs: chosen.map(\.id),
            tryOn: request.tryOn,
            occasion: request.occasion,
            style: request.style,
            weather: request.useWeather ? Self.weatherToday.label : nil,
            renderName: isSampleRender ? "outfit-chaise" : nil,
            reasons: reasons
        )
    }

    private func styleNote(_ request: OutfitRequest) -> String {
        switch (request.occasion, request.style) {
        case (.evening, _): "Pour le soir : du noir aux pieds et à la taille, la couleur reste en haut."
        case (.work, _): "Pour le travail : une seule couleur forte, le reste en noir et indigo."
        case (_, .street): "Version street : le jean large porté bas, la ceinture bien visible."
        case (_, .chic): "Version chic : des lignes nettes, rien de superflu."
        case (_, .relaxed): "Version décontractée : sans accessoire, tout en confort."
        default: "Version minimale : trois couleurs maximum."
        }
    }

    func saveGenerated(_ outfit: GeneratedOutfit) {
        generatedOutfits.insert(outfit, at: 0)
    }

    // MARK: - Cabine d'essayage

    enum PurchaseVerdict {
        /// Rien de semblable : bon achat, et voici avec quoi le porter.
        case buy(pairsWith: [Item])
        /// Une pièce très proche est déjà portée régulièrement.
        case duplicate(Item, wears: Int)
        /// Une pièce très proche dort dans le placard.
        case dormantDuplicate(Item, lastWorn: Date?)
    }

    func verdict(for piece: Item) -> PurchaseVerdict {
        let similar = activeItems
            .filter { $0.category == piece.category }
            .map { (item: $0, distance: Self.colorDistance($0.colorHex, piece.colorHex)) }
            .filter { $0.distance < 0.25 }
            .min { $0.distance < $1.distance }?.item

        if let similar {
            if isDormant(similar) {
                return .dormantDuplicate(similar, lastWorn: lastWorn(similar))
            }
            return .duplicate(similar, wears: wearCount(of: similar))
        }
        return .buy(pairsWith: activeItems.filter { $0.category != piece.category })
    }

    static func colorDistance(_ a: String, _ b: String) -> Double {
        let (r1, g1, b1) = Color.components(hex: a)
        let (r2, g2, b2) = Color.components(hex: b)
        return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).squareRoot()
    }

    // MARK: - Découvrir

    func profile(id: UUID) -> DiscoverProfile? {
        profiles.first { $0.id == id }
    }

    func toggleFriendRequest(_ profile: DiscoverProfile) {
        if friendRequests.contains(profile.id) {
            friendRequests.remove(profile.id)
        } else {
            friendRequests.insert(profile.id)
        }
    }

    func setOpenToOffers(_ open: Bool, swap: Bool, for item: Item) {
        guard var updated = self.item(id: item.id) else { return }
        updated.openToOffers = open
        updated.openToSwap = swap
        update(updated)
    }
}

import SwiftUI

/// Une tenue posée à plat sur un sol (parquet, béton, drap…), comme la photo
/// que le pipeline IA générera à partir de l'OOTD.
struct OutfitFlatLay: View {
    let pieces: [Item]
    let backdropHex: String
    var aspect: CGFloat = 3 / 4

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Color(hex: backdropHex)
                ForEach(Array(placements.enumerated()), id: \.offset) { index, placement in
                    ProductImage(item: placement.item, showsBackground: false)
                        .frame(width: width * placement.size)
                        .rotationEffect(.degrees(tilt(index)))
                        .shadow(color: .black.opacity(0.22), radius: width * 0.012, x: 0, y: width * 0.01)
                        .position(x: width * placement.x, y: height * placement.y)
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipped()
    }

    /// Petite inclinaison différente pour chaque pièce : une vraie photo n'est jamais parfaitement alignée.
    private func tilt(_ index: Int) -> Double {
        [-4, 3, -2, 5, -6, 2][index % 6]
    }

    private struct Placement {
        let item: Item
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    private var placements: [Placement] {
        let hasOuter = pieces.contains { $0.category == .outerwear }
        let hasKnit = pieces.contains { $0.category == .knitwear }
        var result: [Placement] = []
        var seen: [ClothingCategory: Int] = [:]

        // L'ordre compte : les pièces du dessous d'abord, les couches du dessus ensuite.
        let order: [ClothingCategory] = [.bottoms, .baseLayer, .knitwear, .outerwear, .shoes, .accessories]
        for category in order {
            for item in pieces where item.category == category {
                let rank = CGFloat(seen[category, default: 0])
                seen[category, default: 0] += 1
                let shift = rank * 0.08
                switch category {
                case .outerwear:
                    result.append(Placement(item: item, x: 0.34 + shift, y: 0.3, size: 0.6))
                case .knitwear:
                    result.append(hasOuter
                        ? Placement(item: item, x: 0.68, y: 0.3 + shift, size: 0.48)
                        : Placement(item: item, x: 0.38 + shift, y: 0.29, size: 0.62))
                case .baseLayer:
                    result.append(hasOuter || hasKnit
                        ? Placement(item: item, x: 0.76, y: 0.16 + shift, size: 0.36)
                        : Placement(item: item, x: 0.38 + shift, y: 0.28, size: 0.6))
                case .bottoms:
                    result.append(Placement(item: item, x: 0.66, y: 0.64 + shift, size: 0.56))
                case .shoes:
                    result.append(Placement(item: item, x: 0.26 + shift, y: 0.84, size: 0.36))
                case .accessories:
                    result.append(Placement(item: item, x: 0.22, y: 0.62 + shift, size: 0.28))
                }
            }
        }
        return result
    }
}

#Preview {
    let store = WardrobeStore.sample()
    return OutfitFlatLay(pieces: store.feed[4].pieces, backdropHex: store.feed[4].backdropHex)
        .padding()
}

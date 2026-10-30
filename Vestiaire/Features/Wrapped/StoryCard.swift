import SwiftUI

enum StoryCardKind: String, Identifiable, CaseIterable {
    case dna, top5, favorite, color, bestValue, dormant

    var id: String { rawValue }

    /// Les cartes qu'on peut remplir avec les données de la période.
    static func available(for stats: WardrobeStats) -> [StoryCardKind] {
        allCases.filter { kind in
            switch kind {
            case .dna, .dormant: return true
            case .top5: return stats.topItems.count >= 3
            case .color: return stats.topColor != nil
            case .favorite: return stats.favorite != nil
            case .bestValue: return stats.bestValue != nil
            }
        }
    }
}

/// Carte au format story (9:16) : le format de Spotify Wrapped,
/// avec la direction artistique de la boutique (serif fin, petites capitales, filets).
/// Elle ne lit que les données qu'on lui passe, pour pouvoir être transformée en image.
struct StoryCard: View {
    static let size = CGSize(width: 360, height: 640)

    let kind: StoryCardKind
    let stats: WardrobeStats

    private typealias W = Theme.Wrapped

    private var index: Int {
        (StoryCardKind.allCases.firstIndex(of: kind) ?? 0) + 1
    }

    private var backgroundHex: String {
        switch kind {
        case .dna: W.ink
        case .top5: W.paper
        case .favorite: W.card
        case .color: stats.topColor?.hex ?? W.ink
        case .bestValue: W.sapin
        case .dormant: W.vermilion
        }
    }

    var body: some View {
        let foreground = Theme.textColor(onHex: backgroundHex)
        ZStack(alignment: .topLeading) {
            Color(hex: backgroundHex)
                .overlay(alignment: .bottomTrailing) {
                    // Grand numéro de page en filigrane, comme dans un magazine.
                    Text(String(format: "%02d", index))
                        .font(.system(size: 260, weight: .ultraLight, design: .serif))
                        .foregroundStyle(foreground.opacity(0.07))
                        .offset(x: 20, y: 60)
                }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("VESTIAIRE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(4)
                    Spacer()
                    Text("WRAPPED \(stats.period.cardLabel().uppercased())")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                }
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(foreground.opacity(0.35)).frame(height: 0.5)
                }
                Spacer()
                content
                Spacer()
                HStack {
                    Text("vestiaire.app")
                    Spacer()
                    Text("\(index) / \(StoryCardKind.allCases.count)")
                }
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .opacity(0.7)
            }
            .foregroundStyle(foreground)
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .dna:
            VStack(alignment: .leading, spacing: 24) {
                label("Mon ADN de style")
                VStack(alignment: .leading, spacing: 0) {
                    dnaLine("\(stats.itemCount)", "pièces")
                    dnaLine(stats.wornShare.percent, "vraiment portées")
                    dnaLine("\(stats.photographedDays)", "jours en photo")
                    if let color = stats.topColor {
                        dnaLine(color.name.lowercased(), "ma couleur")
                    }
                }
            }
        case .top5:
            VStack(alignment: .leading, spacing: 22) {
                Text("Mes pièces\nles plus portées")
                    .font(Theme.title(40))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stats.topItems.enumerated()), id: \.offset) { position, entry in
                        HStack(spacing: 14) {
                            Text("\(position + 1)")
                                .font(Theme.title(26))
                                .frame(width: 20, alignment: .leading)
                            ProductImage(item: entry.item, showsBackground: false)
                                .frame(width: 44, height: 44)
                                .padding(4)
                                .background(Color(hex: W.card))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.item.brand?.name.uppercased() ?? "SANS MARQUE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.2)
                                Text("\(entry.item.type) · \(portsLabel(entry.wears))")
                                    .font(.system(size: 13))
                                    .opacity(0.7)
                            }
                            .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color(hex: W.ink).opacity(0.12)).frame(height: 0.5)
                        }
                    }
                }
            }
        case .favorite:
            if let favorite = stats.favorite {
                VStack(alignment: .leading, spacing: 16) {
                    label("Ma pièce n°1")
                    ProductImage(item: favorite.item, showsBackground: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(favorite.item.brand?.name.uppercased() ?? "SANS MARQUE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                        Text("\(favorite.item.type) \(favorite.item.colors.first?.lowercased() ?? "")")
                            .font(Theme.title(30))
                        Text(portsLabel(favorite.wears))
                            .font(.system(size: 15))
                            .opacity(0.7)
                    }
                }
            }
        case .color:
            VStack(alignment: .leading, spacing: 12) {
                label("Ma couleur")
                Text((stats.topColor?.name ?? "").lowercased())
                    .font(Theme.title(84))
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                Text("Celle que je porte le plus souvent.")
                    .font(.system(size: 15))
                    .opacity(0.8)
            }
        case .bestValue:
            if let best = stats.bestValue {
                VStack(alignment: .leading, spacing: 14) {
                    label("Ma pièce la plus rentable")
                    Text(best.costPerWear.euros)
                        .font(Theme.title(96))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("par port")
                        .font(Theme.title(26))
                    HStack(spacing: 12) {
                        ProductImage(item: best.item, showsBackground: false)
                            .frame(width: 56, height: 56)
                            .padding(6)
                            .background(Color(hex: W.bone))
                        Text("\(best.item.type)\(best.item.brand.map { " · \($0.name)" } ?? "")")
                            .font(.system(size: 14))
                    }
                    .padding(.top, 8)
                }
            }
        case .dormant:
            VStack(alignment: .leading, spacing: 8) {
                label("Au fond du placard")
                Text("\(stats.dormantCount)")
                    .font(Theme.title(190))
                Text(stats.dormantCount == 1 ? "pièce qui dort\ndepuis 3 mois" : "pièces qui dorment\ndepuis 3 mois")
                    .font(Theme.title(30))
                Text("À porter, ou à revendre.")
                    .font(.system(size: 15))
                    .opacity(0.8)
                    .padding(.top, 6)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
    }

    private func dnaLine(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value)
                .font(Theme.title(46))
            Spacer()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .opacity(0.7)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: W.bone).opacity(0.25)).frame(height: 0.5)
        }
    }
}

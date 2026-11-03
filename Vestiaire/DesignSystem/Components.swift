import SwiftUI
import UIKit

/// Petit titre en capitales espacées, au-dessus des sections.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label)
            .tracking(1.5)
            .foregroundStyle(Theme.muted)
    }
}

/// Onglet texte souligné, façon rayons d'une boutique de luxe.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .tracking(1.2)
                .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(height: 1)
                        .opacity(isSelected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.ink)
            .foregroundStyle(Theme.paper)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .tracking(1.4)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.ink)
            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Photo produit d'une pièce. Si une image du même nom existe dans Assets, elle est utilisée ;
/// sinon on affiche un dessin à plat du vêtement, en attendant les photos générées par le pipeline IA.
struct ProductImage: View {
    let item: Item
    var showsBackground = true
    var aspect: CGFloat = 3 / 4

    var body: some View {
        ZStack {
            if showsBackground {
                Theme.card
            }
            if let name = item.productImageName, UIImage(named: name) != nil {
                // Photo détourée (fond transparent) : voir tools/detourer.swift.
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .padding(showsBackground ? 18 : 0)
            } else {
                GarmentDrawing(item: item)
                    .padding(showsBackground ? 22 : 0)
            }
        }
        .aspectRatio(showsBackground ? aspect : 1, contentMode: .fit)
    }
}

/// Pastille ronde avec l'initiale, en attendant les vraies photos de profil.
struct Avatar: View {
    let name: String
    let hex: String
    var size: CGFloat = 36

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold).width(.expanded))
            .foregroundStyle(Theme.textColor(onHex: hex))
            .frame(width: size, height: size)
            .background(Color(hex: hex))
            .clipShape(Circle())
    }
}

/// Un chiffre clé avec son libellé (fiche pièce, Wrapped).
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(Theme.title(26))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            SectionLabel(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }
}

/// Ligne libellé / valeur des fiches.
struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }
}

/// Option à choisir (occasion, style…) : rectangle fin, plein quand il est choisi.
struct OptionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Theme.ink : Color.clear)
                .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
                .overlay(Rectangle().stroke(isSelected ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Petite étiquette « Exemple » : signale une donnée d'exemple du prototype.
struct SampleBadge: View {
    var body: some View {
        Text("EXEMPLE")
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.muted)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// État vide : ce qui manque, et comment commencer.
struct EmptyState: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.title(22))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Lien texte en capitales, avec une icône fine (barre d'outils du dressing, actions secondaires).
struct ToolLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .light))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Une rangée de vignettes de pièces.
struct PieceStrip: View {
    let pieces: [Item]
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            ForEach(pieces) { piece in
                ProductImage(item: piece)
                    .frame(width: size)
            }
        }
    }
}

/// Liste de pièces à cocher (journal, planning).
struct PieceChecklist: View {
    let items: [Item]
    @Binding var selection: Set<UUID>

    var body: some View {
        ForEach(items) { item in
            let isSelected = selection.contains(item.id)
            Button {
                if isSelected {
                    selection.remove(item.id)
                } else {
                    selection.insert(item.id)
                }
            } label: {
                HStack(spacing: 12) {
                    ProductImage(item: item)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.brand?.name.uppercased() ?? "SANS MARQUE")
                            .font(Theme.label)
                            .tracking(1.2)
                        Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                        if item.status != .active {
                            Text(item.status == .archived ? "Archivée" : "Plus dans le dressing")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18, weight: .light))
                }
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Dispose les éléments en lignes, en passant à la ligne quand il n'y a plus de place.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// Enveloppe de `FlowLayout`, à utiliser comme une pile : `FlowStack { … }`.
struct FlowStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        let layout = FlowLayout(spacing: spacing)
        layout {
            content
        }
    }
}

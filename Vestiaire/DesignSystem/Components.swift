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

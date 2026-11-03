import SwiftUI

/// Statistiques consultables à tout moment, sans attendre le Wrapped.
/// Mêmes calculs que le Wrapped (`WardrobeStore.stats`), à partir du journal des tenues portées.
struct StatsDashboardView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var period: StatsPeriod = .month

    var body: some View {
        let stats = store.stats(for: period)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Statistiques")
                        .font(Theme.title(34))
                    HStack(spacing: 24) {
                        ForEach(StatsPeriod.allCases) { option in
                            Chip(title: option.label, isSelected: period == option) {
                                withAnimation(.snappy) { period = option }
                            }
                        }
                    }
                    Text(stats.includesSampleData
                         ? "Calculées à partir de ton journal de tenues portées. Cette période contient des données d'exemple du prototype."
                         : "Calculées à partir de ton journal de tenues portées.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }

                keyFigures(stats)
                outfitsOverTime
                mostWorn(stats)
                rarelyWorn(stats)
                colors(stats)
                costPerWear(stats)
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func keyFigures(_ stats: WardrobeStats) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 8) {
            StatTile(value: "\(stats.itemCount)", label: "Pièces actives")
            StatTile(value: "\(stats.loggedOutfits)", label: "Tenues portées")
            StatTile(value: "\(stats.loggedDays)", label: "Jours enregistrés")
            StatTile(value: stats.loggedOutfits == 0 ? "—" : stats.wornShare.percent, label: "Du dressing porté")
        }
    }

    /// Une colonne de barres horizontales, d'une seule couleur : une seule série, pas de légende.
    private var outfitsOverTime: some View {
        let counts = store.outfitCounts(for: period)
        let maximum = max(counts.map(\.count).max() ?? 0, 1)
        return section("Tenues portées par \(period == .month ? "semaine" : (period == .year ? "mois" : "année"))") {
            if counts.allSatisfy({ $0.count == 0 }) {
                unavailable("Aucune tenue portée enregistrée sur cette période.")
            } else {
                ForEach(Array(counts.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 10) {
                        Text(entry.label)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 92, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geometry in
                            UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4)
                                .fill(Theme.ink)
                                .frame(width: max(geometry.size.width * Double(entry.count) / Double(maximum), entry.count > 0 ? 2 : 0))
                        }
                        .frame(height: 12)
                        Text("\(entry.count)")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.label) : \(outfitsLabel(entry.count))")
                }
            }
        }
    }

    private func mostWorn(_ stats: WardrobeStats) -> some View {
        section("Les plus portées") {
            if stats.topItems.isEmpty {
                unavailable("Aucune pièce portée sur cette période.")
            } else {
                ForEach(Array(stats.topItems.enumerated()), id: \.offset) { position, entry in
                    itemRow(entry.item, leading: "\(position + 1)", trailing: portsLabel(entry.wears))
                }
            }
        }
    }

    private func rarelyWorn(_ stats: WardrobeStats) -> some View {
        section("Peu ou pas portées") {
            if stats.itemCount == 0 {
                unavailable("Ton dressing actif est vide.")
            } else if stats.rarelyWorn.isEmpty {
                Text("Toutes tes pièces ont été portées au moins deux fois sur cette période.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(Array(stats.rarelyWorn.enumerated()), id: \.offset) { _, entry in
                    itemRow(entry.item, leading: nil, trailing: entry.wears == 0 ? "Jamais" : portsLabel(entry.wears))
                }
            }
        }
    }

    /// Les couleurs portées : la pastille montre la couleur elle-même, toujours accompagnée de son nom.
    private func colors(_ stats: WardrobeStats) -> some View {
        let maximum = max(stats.colors.first?.wears ?? 0, 1)
        return section("Couleurs les plus portées") {
            if stats.colors.isEmpty {
                unavailable("Pas encore de couleur portée sur cette période.")
            } else {
                ForEach(Array(stats.colors.prefix(6).enumerated()), id: \.offset) { _, color in
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color(hex: color.hex))
                            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                            .frame(width: 14, height: 14)
                        Text(color.name)
                            .font(.system(size: 13))
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geometry in
                            UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4)
                                .fill(Theme.ink)
                                .frame(width: geometry.size.width * Double(color.wears) / Double(maximum))
                        }
                        .frame(height: 12)
                        Text(portsLabel(color.wears))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 64, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(color.name) : \(portsLabel(color.wears))")
                }
            }
        }
    }

    private func costPerWear(_ stats: WardrobeStats) -> some View {
        let withoutPrice = store.activeItems.filter { $0.pricePaid == nil }.count
        return section("Coût par port · depuis le début") {
            if stats.costPerWear.isEmpty {
                unavailable("Il faut un prix payé et au moins un port pour calculer le coût par port.")
            } else {
                ForEach(Array(stats.costPerWear.enumerated()), id: \.offset) { _, entry in
                    itemRow(entry.item, leading: nil, trailing: "\(entry.costPerWear.euros) / port")
                }
            }
            if withoutPrice > 0 {
                Text(withoutPrice == 1 ? "1 pièce sans prix payé : son coût par port ne peut pas être calculé." : "\(withoutPrice) pièces sans prix payé : leur coût par port ne peut pas être calculé.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Éléments

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title)
                .padding(.bottom, 8)
            content()
        }
    }

    private func unavailable(_ text: String) -> some View {
        Label(text, systemImage: "minus.circle")
            .font(.system(size: 14))
            .foregroundStyle(Theme.muted)
    }

    private func itemRow(_ item: Item, leading: String?, trailing: String) -> some View {
        NavigationLink(value: item.id) {
            HStack(spacing: 12) {
                if let leading {
                    Text(leading)
                        .font(Theme.title(20))
                        .frame(width: 18, alignment: .leading)
                }
                ProductImage(item: item)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.brand?.name.uppercased() ?? "SANS MARQUE")
                        .font(Theme.label)
                        .tracking(1.2)
                    Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                .lineLimit(1)
                Spacer()
                Text(trailing)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

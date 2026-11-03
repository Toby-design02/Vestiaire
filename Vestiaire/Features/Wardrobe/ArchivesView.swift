import SwiftUI

/// Archives : les pièces et les tenues rangées de côté, restaurables.
/// Une pièce archivée sort du dressing actif et des tenues proposées, mais garde son historique de port.
/// À ne pas confondre avec une pièce vendue ou donnée, ni avec une tenue portée.
struct ArchivesView: View {
    @Environment(WardrobeStore.self) private var store

    var body: some View {
        let items = store.archivedItems
        let outfits = store.generatedOutfits.filter(\.isArchived)
        let gone = store.items.filter { $0.status == .sold || $0.status == .donated }
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Archives")
                        .font(Theme.title(34))
                    Text("Ce que tu ranges de côté sans t'en séparer : hors saison, à retoucher, prêté… Les pièces archivées ne sont plus proposées dans les tenues, mais leurs ports restent dans ton journal.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Pièces archivées · \(items.count)")
                        .padding(.bottom, 4)
                    if items.isEmpty {
                        Text("Aucune pièce archivée. Depuis la fiche d'une pièce, touche « Archiver ».")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .padding(.vertical, 12)
                    }
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            NavigationLink(value: item.id) {
                                HStack(spacing: 12) {
                                    ProductImage(item: item)
                                        .frame(width: 56)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.brand?.name.uppercased() ?? "SANS MARQUE")
                                            .font(Theme.label)
                                            .tracking(1.2)
                                        Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                            .font(.system(size: 14))
                                        Text("\(portsLabel(store.wearCount(of: item))) · dernier le \(store.lastWorn(item)?.shortFR ?? "—")")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button("Restaurer") {
                                store.setStatus(.active, for: item)
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.line).frame(height: 0.5)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Tenues proposées archivées · \(outfits.count)")
                        .padding(.bottom, 4)
                    if outfits.isEmpty {
                        Text("Aucune tenue archivée. Depuis une tenue proposée, touche « Archiver cette tenue » pour l'enlever de l'historique.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .padding(.vertical, 12)
                    }
                    ForEach(outfits) { outfit in
                        HStack(spacing: 12) {
                            NavigationLink(value: outfit) {
                                HStack(spacing: 12) {
                                    GeneratedOutfitImage(outfit: outfit)
                                        .frame(width: 56)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(outfit.date.shortFR.uppercased())
                                            .font(Theme.label)
                                            .tracking(1.2)
                                        Text("\(outfit.occasion.label) · \(outfit.style.label)")
                                            .font(.system(size: 14))
                                        let worn = store.timesWorn(outfit)
                                        Text(worn == 0 ? "Jamais portée" : "Portée \(worn) fois")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button("Restaurer") {
                                store.setArchived(false, for: outfit)
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.line).frame(height: 0.5)
                        }
                    }
                }

                if !gone.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel("Vendues ou données · \(gone.count)")
                            .padding(.bottom, 4)
                        Text("Elles ont quitté ton vestiaire : elles ne se restaurent pas, mais leur historique reste dans ton journal.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .padding(.bottom, 6)
                        ForEach(gone) { item in
                            HStack(spacing: 12) {
                                ProductImage(item: item)
                                    .frame(width: 40)
                                Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                    .font(.system(size: 14))
                                Spacer()
                                Text(item.status == .sold ? "Vendue" : "Donnée")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}

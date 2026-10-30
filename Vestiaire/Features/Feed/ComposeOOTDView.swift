import SwiftUI

/// Composer son OOTD. Plus tard : la photo miroir, et le pipeline reconnaît les pièces.
/// Pour l'instant on choisit les pièces dans son vestiaire.
struct ComposeOOTDView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var audience: Audience = .friends
    @State private var caption = ""

    private var selected: [Item] {
        store.activeItems.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OutfitFlatLay(pieces: selected, backdropHex: "D9D3C7")
                        .frame(maxWidth: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .frame(maxWidth: .infinity)
                        .animation(.snappy, value: selectedIDs)

                    ForEach(ClothingCategory.allCases) { category in
                        categoryRow(category)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Qui peut voir")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.nightMuted)
                        HStack(spacing: 8) {
                            audienceButton("Mes amis", .friends)
                            audienceButton("Tout le monde", .everyone)
                        }
                    }
                    .padding(.horizontal, 16)

                    TextField("Ajoute une légende…", text: $caption)
                        .font(.system(size: 15))
                        .padding(14)
                        .background(Theme.nightRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.publishOOTD(items: selected, caption: trimmed.isEmpty ? nil : trimmed, audience: audience)
                    dismiss()
                } label: {
                    Text("Publier")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selected.isEmpty ? Theme.nightRaised : Theme.bone)
                        .foregroundStyle(selected.isEmpty ? Theme.nightMuted : Theme.night)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(Theme.night)
            }
            .background(Theme.night)
            .navigationTitle("Mon OOTD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                selectedIDs = Set(store.lastOutfitItems.map(\.id))
            }
        }
        .tint(Theme.bone)
        .preferredColorScheme(.dark)
    }

    private func categoryRow(_ category: ClothingCategory) -> some View {
        let pieces = store.activeItems.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 10) {
            Text(category.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.nightMuted)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pieces) { piece in
                        let isSelected = selectedIDs.contains(piece.id)
                        Button {
                            if isSelected {
                                selectedIDs.remove(piece.id)
                            } else {
                                selectedIDs.insert(piece.id)
                            }
                        } label: {
                            ProductImage(item: piece)
                                .frame(width: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Theme.bone : .clear, lineWidth: 2))
                                .opacity(isSelected ? 1 : 0.55)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func audienceButton(_ title: String, _ value: Audience) -> some View {
        Button {
            audience = value
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(audience == value ? Theme.bone : Theme.nightRaised)
                .foregroundStyle(audience == value ? Theme.night : Theme.bone)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

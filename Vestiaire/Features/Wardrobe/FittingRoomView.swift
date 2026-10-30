import PhotosUI
import SwiftUI

/// En cabine d'essayage : « est-ce que je devrais acheter ce pantalon bleu ? »
/// L'app compare la pièce avec le dressing avant l'achat.
struct FittingRoomView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var description = ""
    @State private var checked: Item?
    @State private var tryOnOutfit: GeneratedOutfit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Cabine d'essayage")
                        Text("Je l'achète ?")
                            .font(Theme.title(34))
                        Text("Prends-toi en photo dans la cabine et dis-nous ce que tu essaies. On regarde ce que tu as déjà.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            Theme.card
                            if let data = photoData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 26, weight: .light))
                                    Text("PHOTO EN CABINE")
                                        .font(Theme.label)
                                        .tracking(1.5)
                                }
                                .foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(height: 300)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Ce que tu essaies")
                        TextField("Ex : pantalon bleu", text: $description)
                            .font(.system(size: 16))
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.line).frame(height: 1)
                            }
                    }

                    Button("Vérifier mon dressing") {
                        withAnimation(.snappy) {
                            checked = TryOnPiece(description: description).item
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(description.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                    if let checked {
                        verdictView(for: checked)
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .navigationDestination(item: $tryOnOutfit) { outfit in
                GeneratedOutfitView(outfit: outfit)
            }
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
            .onChange(of: photoItem) { _, newValue in
                Task {
                    photoData = try? await newValue?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    @ViewBuilder
    private func verdictView(for piece: Item) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            switch store.verdict(for: piece) {
            case .buy(let pairs):
                verdictTitle("Oui, fonce.", color: Theme.positive)
                Text("Tu n'as rien de semblable dans ton rayon \(piece.category.label.lowercased()). Il irait avec :")
                    .font(.system(size: 14))
                HStack(spacing: 8) {
                    ForEach(pairs.prefix(4)) { item in
                        ProductImage(item: item)
                            .frame(width: 64)
                    }
                }
                Button("Voir dans une tenue") {
                    var request = OutfitRequest()
                    request.tryOn = TryOnPiece(description: description, photo: photoData)
                    let outfit = store.generateOutfit(request)
                    store.saveGenerated(outfit)
                    tryOnOutfit = outfit
                }
                .buttonStyle(SecondaryButtonStyle())
            case .duplicate(let item, let wears):
                verdictTitle("Pas sûr.", color: Theme.ink)
                Text("Tu as déjà ton \(item.type.lowercased()) \(item.colors.first?.lowercased() ?? ""), \(portsLabel(wears)). Celui-ci ferait doublon.")
                    .font(.system(size: 14))
                similarRow(item)
            case .dormantDuplicate(let item, let lastWorn):
                verdictTitle("Attention.", color: Theme.accent)
                Text("Tu as déjà un \(item.type.lowercased()) \(item.colors.first?.lowercased() ?? "") très proche, que tu ne portes plus\(lastWorn.map { " depuis le \($0.shortFR)" } ?? ""). Et si tu le ressortais ?")
                    .font(.system(size: 14))
                similarRow(item)
            }
        }
        .padding(18)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }

    private func verdictTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.title(30))
            .foregroundStyle(color)
    }

    private func similarRow(_ item: Item) -> some View {
        NavigationLink(value: item.id) {
            HStack(spacing: 12) {
                ProductImage(item: item)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.brand?.name.uppercased() ?? "DANS TON DRESSING")
                        .font(Theme.label)
                        .tracking(1.2)
                    Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .light))
            }
        }
        .buttonStyle(.plain)
    }
}

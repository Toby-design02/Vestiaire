import PhotosUI
import SwiftUI

/// Mes envies : la liste privée des vêtements envisagés avant achat.
struct WishlistView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var newWish: Wish?

    var body: some View {
        let considered = store.consideredWishes
        let purchased = store.purchasedWishes
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mes envies")
                        .font(Theme.title(34))
                    Text("Ce que tu envisages d'acheter, comparé à ce que tu as déjà. Ta liste est privée.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }

                Button("Ajouter un article") {
                    newWish = Wish(description: "")
                }
                .buttonStyle(PrimaryButtonStyle())

                if considered.isEmpty && purchased.isEmpty {
                    EmptyState(
                        title: "Ta liste est vide",
                        message: "Ajoute un article à la main, depuis la cabine d'essayage ou depuis « Pour toi » dans Découvrir."
                    )
                }

                if !considered.isEmpty {
                    section("Envisagés · \(considered.count)", wishes: considered)
                }
                if !purchased.isEmpty {
                    section("Achetés · \(purchased.count)", wishes: purchased)
                }
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $newWish) { wish in
            WishEditor(draft: wish)
        }
    }

    private func section(_ title: String, wishes: [Wish]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title)
                .padding(.bottom, 4)
            ForEach(wishes) { wish in
                NavigationLink(value: WardrobeRoute.wish(wish.id)) {
                    WishRow(wish: wish)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WishRow: View {
    @Environment(WardrobeStore.self) private var store
    let wish: Wish

    var body: some View {
        HStack(spacing: 14) {
            WishImage(wish: wish)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(wish.brand?.uppercased() ?? "SANS MARQUE")
                        .font(Theme.label)
                        .tracking(1.2)
                    if wish.isSample {
                        SampleBadge()
                    }
                }
                Text(wish.description)
                    .font(.system(size: 14))
                Text([wish.estimatedPrice?.euros, wish.isPurchased ? "Acheté" : similarLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(wish.isPurchased ? Theme.positive : Theme.muted)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }

    private var similarLabel: String {
        let count = wish.similarItemIDs.count
        return count == 0 ? "Rien de semblable dans ton dressing" : (count == 1 ? "1 pièce semblable dans ton dressing" : "\(count) pièces semblables dans ton dressing")
    }
}

/// La photo de l'article si elle existe, sinon son dessin à plat.
struct WishImage: View {
    let wish: Wish

    var body: some View {
        if let data = wish.photo, let image = UIImage(data: data) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            ProductImage(item: wish.item)
        }
    }
}

/// Un article envisagé : comparaison avec le dressing, puis « Je l'ai acheté » ou « Retirer ».
struct WishDetailView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let wishID: UUID

    @State private var isEditing = false
    @State private var isConfirmingRemove = false

    var body: some View {
        if let wish = store.wish(id: wishID) {
            content(wish)
        } else {
            Text("Cet article n'est plus dans tes envies.")
                .foregroundStyle(Theme.muted)
        }
    }

    private func content(_ wish: Wish) -> some View {
        let similar = wish.similarItemIDs.compactMap { store.item(id: $0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WishImage(wish: wish)
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .background(Theme.card)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(wish.brand?.uppercased() ?? "SANS MARQUE")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(2)
                        if wish.isSample {
                            SampleBadge()
                        }
                    }
                    Text(wish.description)
                        .font(Theme.title(28))
                    Text(wish.estimatedPrice.map { "Prix estimé \($0.euros)" } ?? "Prix non renseigné")
                        .font(.system(size: 14))
                    Text("Ajouté le \(wish.addedAt.shortFR) · \(wish.source.label)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                    if let link = wish.url, let url = URL(string: link), url.scheme?.hasPrefix("http") == true {
                        Link(destination: url) {
                            Label(url.host ?? link, systemImage: "arrow.up.right.square")
                                .font(.system(size: 13))
                                .underline()
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Déjà dans ton dressing")
                        .padding(.bottom, 6)
                    if similar.isEmpty {
                        Text("Rien de semblable dans ton rayon \(wish.category.label.lowercased()) : pas de doublon en vue.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(similar) { item in
                        NavigationLink(value: item.id) {
                            HStack(spacing: 12) {
                                ProductImage(item: item)
                                    .frame(width: 56)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                        .font(.system(size: 14))
                                    Text("\(portsLabel(store.wearCount(of: item)))\(item.status == .archived ? " · archivée" : "")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .light))
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    if let itemID = wish.purchasedItemID {
                        Text("Acheté : la pièce est dans ton dressing.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.positive)
                        NavigationLink("Voir la pièce", value: itemID)
                            .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button("Je l'ai acheté") {
                            store.markPurchased(wish)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Text("La pièce entre dans ton dressing, avec le prix estimé comme prix payé.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                        Button("Modifier") { isEditing = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button("Retirer de mes envies") { isConfirmingRemove = true }
                        .font(.system(size: 13))
                        .underline()
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            WishEditor(draft: wish)
        }
        .confirmationDialog("Retirer cet article de tes envies ?", isPresented: $isConfirmingRemove, titleVisibility: .visible) {
            Button("Retirer", role: .destructive) {
                store.removeWish(wish)
                dismiss()
            }
        }
    }
}

/// Ajouter ou modifier un article envisagé. Tout est saisi à la main : aucune information n'est lue sur le web.
struct WishEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let draft: Wish

    @State private var description: String
    @State private var category: ClothingCategory
    @State private var brand: String
    @State private var price: String
    @State private var url: String
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var hasPickedCategory = false

    init(draft: Wish) {
        self.draft = draft
        _description = State(initialValue: draft.description)
        _category = State(initialValue: draft.category)
        _brand = State(initialValue: draft.brand ?? "")
        _price = State(initialValue: draft.estimatedPrice.map { String(Int($0)) } ?? "")
        _url = State(initialValue: draft.url ?? "")
        _photo = State(initialValue: draft.photo)
        // Un rayon déjà corrigé à la main n'est plus recalculé depuis la description.
        _hasPickedCategory = State(initialValue: draft.category != PieceDescription(draft.description).category)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let isExisting = store.wish(id: draft.id) != nil
        NavigationStack {
            Form {
                Section {
                    TextField("Ex : pantalon large bleu", text: $description)
                    Picker("Rayon", selection: Binding(get: { category }, set: { category = $0; hasPickedCategory = true })) {
                        ForEach(ClothingCategory.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    TextField("Marque (facultatif)", text: $brand)
                } header: {
                    Text("L'article")
                } footer: {
                    Text("Le rayon et la couleur sont lus dans la description ; tu peux corriger le rayon.")
                }

                Section {
                    TextField("Prix estimé en € (facultatif)", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Lien (facultatif)", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Le lien est gardé tel quel : aucune information n'est récupérée automatiquement.")
                }

                Section("Photo (facultative)") {
                    if let data = photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? "Ajouter une photo" : "Changer la photo", systemImage: "photo")
                    }
                    if photo != nil {
                        Button("Retirer la photo", role: .destructive) {
                            photo = nil
                            photoItem = nil
                        }
                    }
                }
            }
            .tint(Theme.ink)
            .navigationTitle(isExisting ? "Modifier l'envie" : "Nouvelle envie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isExisting ? "Enregistrer" : "Ajouter") { save(isExisting: isExisting) }
                        .disabled(trimmedDescription.isEmpty)
                }
            }
            .onChange(of: description) { _, newValue in
                // Tant que l'utilisateur n'a pas choisi de rayon, on suit la description.
                if !hasPickedCategory {
                    category = PieceDescription(newValue).category
                }
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    photo = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private func save(isExisting: Bool) {
        let parsed = PieceDescription(trimmedDescription)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var wish = draft
        wish.description = trimmedDescription
        wish.category = category
        wish.colorName = parsed.colorName
        wish.colorHex = parsed.colorHex
        wish.brand = trimmedBrand.isEmpty ? parsed.brand : trimmedBrand
        wish.estimatedPrice = Double(price.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        wish.url = trimmedURL.isEmpty ? nil : trimmedURL
        wish.photo = photo
        if isExisting {
            store.update(wish)
        } else {
            store.addWish(wish)
        }
        dismiss()
    }
}

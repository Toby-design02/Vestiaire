import SwiftUI

/// Fiche d'une pièce, comme une fiche produit d'e-shop de luxe :
/// grande photo, marque, nom, puis les infos repliées en accordéon.
struct ItemDetailView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID

    @State private var isEditingBrand = false
    @State private var isMerging = false
    @State private var isRemoving = false
    @State private var isClassifying = false
    @State private var openSection: String? = "Détails"

    var body: some View {
        if let item = store.item(id: itemID) {
            content(item)
        } else {
            Text("Cette pièce n'est plus dans ton vestiaire.")
                .foregroundStyle(Theme.muted)
        }
    }

    private func content(_ item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                gallery(item)
                if item.status == .archived {
                    archivedBanner(item)
                }
                titleBlock(item)
                    .padding(.top, 24)
                statsRow(item)
                    .padding(.top, 28)
                VStack(spacing: 0) {
                    accordion("Détails") { details(item) }
                    accordion("Saisons, occasions et étiquettes") { attributes(item) }
                    accordion("Prix et revente") { prices(item) }
                    accordion("Vendre ou échanger") { resale(item) }
                    accordion("Photos sources") { sources(item) }
                }
                .padding(.top, 28)
                actions(item)
                    .padding(.top, 32)
            }
            .padding(.bottom, 48)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingBrand) {
            BrandEditor(item: item)
        }
        .sheet(isPresented: $isMerging) {
            MergePicker(item: item)
        }
        .sheet(isPresented: $isClassifying) {
            ItemAttributesEditor(item: item)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.toggleFavorite(item)
                } label: {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(item.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }
        }
        .confirmationDialog("Cette pièce sort de ton vestiaire", isPresented: $isRemoving, titleVisibility: .visible) {
            Button("Je l'ai vendue") {
                store.setStatus(.sold, for: item)
                dismiss()
            }
            Button("Je l'ai donnée") {
                store.setStatus(.donated, for: item)
                dismiss()
            }
            Button("Ce n'est pas à moi", role: .destructive) {
                store.delete(item)
                dismiss()
            }
        }
    }

    /// Photo produit, puis les photos d'origine (qui restent sur l'iPhone).
    private func gallery(_ item: Item) -> some View {
        TabView {
            ProductImage(item: item)
            ForEach(item.sourcePhotos, id: \.assetIdentifier) { photo in
                ZStack {
                    Theme.card
                    VStack(spacing: 10) {
                        Image(systemName: "lock")
                            .font(.system(size: 20, weight: .light))
                        Text("Photo d'origine · \(photo.angle.label)")
                            .font(Theme.label)
                            .tracking(1.2)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(Theme.muted)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 500)
        .background(Theme.card)
    }

    private func titleBlock(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let brand = item.brand {
                Text(brand.name.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
            } else {
                Button {
                    isEditingBrand = true
                } label: {
                    Label("Ajouter la marque", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                }
                .foregroundStyle(Theme.accent)
            }
            Text("\(item.type) \(item.colors.joined(separator: ", ").lowercased())")
                .font(Theme.title(28))
            if let paid = item.pricePaid {
                HStack(spacing: 6) {
                    Text(paid.euros)
                    if let resale = item.resaleValue {
                        Text("·").foregroundStyle(Theme.muted)
                        Text("revente estimée \(resale.euros)")
                            .foregroundStyle(Theme.muted)
                    }
                }
                .font(.system(size: 14))
            }
            if let brand = item.brand, brand.source != .user {
                Text("Marque lue \(brand.source == .photo ? "sur la photo" : "par recherche web") · fiable à \(brand.confidence.percent)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
    }

    private func statsRow(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 16) {
            StatTile(value: "\(store.wearCount(of: item))", label: "Ports")
            StatTile(value: store.wearRate(of: item).percent, label: "Taux")
            StatTile(value: store.costPerWear(of: item)?.euros ?? "—", label: "Par port")
        }
        .padding(.horizontal, 20)
    }

    /// Section repliable, façon « Composition et entretien » des fiches produit.
    private func accordion<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let isOpen = openSection == title
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { openSection = isOpen ? nil : title }
            } label: {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.5)
                    Spacer()
                    Image(systemName: isOpen ? "minus" : "plus")
                        .font(.system(size: 12, weight: .light))
                }
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                content()
                    .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }

    private func details(_ item: Item) -> some View {
        let rows: [(String, String?)] = [
            ("Rayon", item.category.label),
            ("Couleurs", item.colors.joined(separator: ", ")),
            ("Motif", item.pattern),
            ("Matière", item.material),
            ("Coupe", item.fit),
            ("Col", item.collar),
            ("Face", item.frontDetails),
            ("Dos", item.backDetails),
            ("Textes lus", item.detectedTexts.isEmpty ? nil : item.detectedTexts.joined(separator: ", ")),
            ("Dernier port", store.lastWorn(item)?.shortFR ?? "Jamais"),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.filter { $0.1 != nil }, id: \.0) { row in
                DetailRow(label: row.0, value: row.1 ?? "")
            }
        }
    }

    private func prices(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailRow(label: "Prix payé", value: item.pricePaid?.euros ?? "À compléter")
            DetailRow(label: "Prix neuf", value: item.priceNew?.euros ?? "—")
            DetailRow(label: "Valeur de revente estimée", value: item.resaleValue?.euros ?? "—")
            if let paid = item.pricePaid, let resale = item.resaleValue {
                let difference = resale - paid
                DetailRow(
                    label: difference >= 0 ? "Plus-value" : "Moins-value",
                    value: abs(difference).euros,
                    valueColor: difference >= 0 ? Theme.positive : Theme.negative
                )
            }
        }
    }

    /// Seconde main : la pièce apparaît dans Découvrir pour les autres utilisateurs.
    private func resale(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Accepter les offres", isOn: Binding(
                get: { item.openToOffers },
                set: { store.setOpenToOffers($0, swap: item.openToSwap, for: item) }
            ))
            Toggle("Accepter les échanges", isOn: Binding(
                get: { item.openToSwap },
                set: { store.setOpenToOffers(item.openToOffers, swap: $0, for: item) }
            ))
            Text(item.openToOffers || item.openToSwap
                 ? "Ta pièce est visible dans la seconde main de Découvrir\(item.resaleValue.map { ", autour de \($0.euros)" } ?? "")."
                 : "Ta pièce reste privée. Active une option pour recevoir des propositions.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .font(.system(size: 14))
        .tint(Theme.ink)
    }

    private func sources(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.sourcePhotos.count) photos de ta galerie montrent cette pièce. Elles restent sur ton iPhone : glisse la grande photo pour les voir.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
    }

    private func archivedBanner(_ item: Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 16, weight: .light))
            VStack(alignment: .leading, spacing: 2) {
                Text("PIÈCE ARCHIVÉE")
                    .font(Theme.label)
                    .tracking(1.5)
                Text("Hors du dressing actif et des tenues proposées. Son historique est conservé.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Restaurer") { store.setStatus(.active, for: item) }
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func attributes(_ item: Item) -> some View {
        let tagNames = item.tagIDs.compactMap { store.tag(id: $0)?.name }.sorted()
        return VStack(alignment: .leading, spacing: 0) {
            DetailRow(label: "Favori", value: item.isFavorite ? "Oui" : "Non")
            DetailRow(label: "Saisons", value: item.seasons.isEmpty ? "À renseigner" : Season.allCases.filter(item.seasons.contains).map(\.label).joined(separator: ", "))
            DetailRow(label: "Occasions", value: item.occasions.isEmpty ? "À renseigner" : Occasion.allCases.filter(item.occasions.contains).map(\.label).joined(separator: ", "))
            DetailRow(label: "Étiquettes", value: tagNames.isEmpty ? "Aucune" : tagNames.joined(separator: ", "))
            Button("Modifier") { isClassifying = true }
                .font(.system(size: 13, weight: .semibold))
                .underline()
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)
        }
    }

    private func actions(_ item: Item) -> some View {
        VStack(spacing: 10) {
            Button("Modifier la marque") { isEditingBrand = true }
                .buttonStyle(PrimaryButtonStyle())
            Button("Fusionner un doublon") { isMerging = true }
                .buttonStyle(SecondaryButtonStyle())
            if item.status == .archived {
                Button("Restaurer dans le dressing") { store.setStatus(.active, for: item) }
                    .buttonStyle(SecondaryButtonStyle())
            } else if item.status == .active {
                Button("Archiver") { store.setStatus(.archived, for: item) }
                    .buttonStyle(SecondaryButtonStyle())
                Text("Archiver la range de côté : elle n'est plus proposée dans les tenues, mais son historique reste.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            if item.status == .active || item.status == .archived {
                Button("Je ne l'ai plus") { isRemoving = true }
                    .font(.system(size: 13))
                    .underline()
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
            } else {
                Text(item.status == .sold ? "Vendue : elle n'est plus dans ton vestiaire." : "Donnée : elle n'est plus dans ton vestiaire.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Compléter ou corriger la marque à la main.
struct BrandEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var name = ""
    @State private var model = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Marque", text: $name)
                TextField("Modèle (facultatif)", text: $model)
            }
            .navigationTitle("Marque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                name = item.brand?.name ?? ""
                model = item.brand?.model ?? ""
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        var updated = item
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.brand = BrandInfo(name: trimmedName, model: trimmedModel.isEmpty ? nil : trimmedModel, confidence: 1, source: .user)
        store.update(updated)
        dismiss()
    }
}

/// Choisir le doublon à fusionner dans la pièce affichée.
struct MergePicker: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    var body: some View {
        let candidates = store.activeItems.filter { $0.category == item.category && $0.id != item.id }
        NavigationStack {
            List(candidates) { candidate in
                Button {
                    store.merge(candidate, into: item)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ProductImage(item: candidate)
                            .frame(width: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.brand?.name ?? "Marque inconnue")
                                .font(Theme.label)
                            Text("\(candidate.type) \(candidate.colors.first?.lowercased() ?? "")")
                                .font(.subheadline)
                        }
                    }
                }
                .foregroundStyle(Theme.ink)
            }
            .navigationTitle("Quel est le doublon ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let store = WardrobeStore.sample()
    return NavigationStack {
        ItemDetailView(itemID: store.items[0].id)
    }
    .environment(store)
}

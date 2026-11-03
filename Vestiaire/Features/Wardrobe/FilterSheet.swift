import SwiftUI

/// Filtres du dressing : rayon, couleur, saison, occasion, matière, favoris et étiquettes, combinables.
/// Chaque choix est appliqué aux pièces ; le nombre de résultats se met à jour en direct.
struct FilterSheet: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: WardrobeFilter

    @State private var draft = WardrobeFilter()

    private var colors: [String] {
        Array(Set(store.activeItems.flatMap(\.colors))).sorted()
    }

    private var materials: [String] {
        Array(Set(store.activeItems.compactMap(\.material))).sorted()
    }

    var body: some View {
        let count = store.activeItems.filter(draft.matches).count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    group("Rayon") {
                        ForEach(ClothingCategory.allCases) { option in
                            OptionPill(title: option.label, isSelected: draft.categories.contains(option)) {
                                draft.categories.toggle(option)
                            }
                        }
                    }
                    group("Couleur") {
                        ForEach(colors, id: \.self) { color in
                            OptionPill(title: color, isSelected: draft.colors.contains(color)) {
                                draft.colors.toggle(color)
                            }
                        }
                    }
                    group("Saison") {
                        ForEach(Season.allCases) { option in
                            OptionPill(title: option.label, isSelected: draft.seasons.contains(option)) {
                                draft.seasons.toggle(option)
                            }
                        }
                    }
                    group("Occasion") {
                        ForEach(Occasion.allCases) { option in
                            OptionPill(title: option.label, isSelected: draft.occasions.contains(option)) {
                                draft.occasions.toggle(option)
                            }
                        }
                    }
                    group("Matière") {
                        ForEach(materials, id: \.self) { material in
                            OptionPill(title: material, isSelected: draft.materials.contains(material)) {
                                draft.materials.toggle(material)
                            }
                        }
                    }
                    group("Favoris") {
                        OptionPill(title: "Favoris uniquement", isSelected: draft.favoritesOnly) {
                            draft.favoritesOnly.toggle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SectionLabel("Étiquettes")
                            Spacer()
                            NavigationLink("Gérer") {
                                TagManagerView()
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink)
                        }
                        if store.tags.isEmpty {
                            Text("Aucune étiquette. Crée les tiennes (« Uniforme », « À retoucher »…) avec « Gérer ».")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        } else {
                            FlowStack {
                                ForEach(store.tags) { tag in
                                    OptionPill(title: tag.name, isSelected: draft.tagIDs.contains(tag.id)) {
                                        draft.tagIDs.toggle(tag.id)
                                    }
                                }
                            }
                        }
                    }

                    Text("Les saisons, occasions, favoris et étiquettes se renseignent sur la fiche de chaque pièce. Une pièce sans saison n'apparaît pas quand on filtre par saison.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(20)
            }
            .background(Theme.paper)
            .safeAreaInset(edge: .bottom) {
                Button(count == 1 ? "Voir 1 pièce" : "Voir \(count) pièces") {
                    filter = draft
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(16)
                .background(Theme.paper)
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tout effacer") { draft = WardrobeFilter() }
                        .disabled(draft.isEmpty)
                }
            }
            .onAppear { draft = filter }
            .onChange(of: store.tags) { _, tags in
                // Une étiquette supprimée ne doit pas rester dans le filtre.
                draft.tagIDs.formIntersection(tags.map(\.id))
            }
        }
        .tint(Theme.ink)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            FlowStack {
                content()
            }
        }
    }
}

extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}

/// Créer, renommer et supprimer les étiquettes personnalisées.
struct TagManagerView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var newName = ""
    @State private var renamed: ItemTag?
    @State private var renameText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Nouvelle étiquette", text: $newName)
                        .onSubmit(add)
                    Button("Créer", action: add)
                        .disabled(trimmed(newName).isEmpty)
                }
            } footer: {
                Text("Les étiquettes sont privées. Supprimer une étiquette la retire de toutes les pièces.")
            }

            Section("Mes étiquettes") {
                if store.tags.isEmpty {
                    Text("Aucune étiquette pour l'instant.")
                        .foregroundStyle(Theme.muted)
                }
                ForEach(store.tags) { tag in
                    let count = store.items.filter { $0.tagIDs.contains(tag.id) }.count
                    HStack {
                        Text(tag.name)
                        Spacer()
                        Text(count == 1 ? "1 pièce" : "\(count) pièces")
                            .foregroundStyle(Theme.muted)
                    }
                    .swipeActions {
                        Button("Supprimer", role: .destructive) {
                            store.deleteTag(tag)
                        }
                        Button("Renommer") {
                            renameText = tag.name
                            renamed = tag
                        }
                    }
                    .contextMenu {
                        Button("Renommer") {
                            renameText = tag.name
                            renamed = tag
                        }
                        Button("Supprimer", role: .destructive) {
                            store.deleteTag(tag)
                        }
                    }
                }
            }
        }
        .tint(Theme.ink)
        .navigationTitle("Étiquettes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Renommer l'étiquette", isPresented: Binding(get: { renamed != nil }, set: { if !$0 { renamed = nil } })) {
            TextField("Nom", text: $renameText)
            Button("Annuler", role: .cancel) { renamed = nil }
            Button("Enregistrer") {
                if let renamed, !trimmed(renameText).isEmpty {
                    store.rename(renamed, to: trimmed(renameText))
                }
                renamed = nil
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let name = trimmed(newName)
        guard !name.isEmpty else { return }
        store.addTag(named: name)
        newName = ""
    }
}

/// Favori, saisons, occasions et étiquettes d'une pièce : ce qui alimente les filtres.
struct ItemAttributesEditor: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var draft: Item

    init(item: Item) {
        self.item = item
        _draft = State(initialValue: item)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Favori", isOn: $draft.isFavorite)
                }
                Section("Saisons") {
                    ForEach(Season.allCases) { season in
                        Toggle(season.label, isOn: membership(season, in: \.seasons))
                    }
                }
                Section("Occasions") {
                    ForEach(Occasion.allCases) { occasion in
                        Toggle(occasion.label, isOn: membership(occasion, in: \.occasions))
                    }
                }
                Section {
                    ForEach(store.tags) { tag in
                        Toggle(tag.name, isOn: membership(tag.id, in: \.tagIDs))
                    }
                    NavigationLink("Gérer les étiquettes") {
                        TagManagerView()
                    }
                } header: {
                    Text("Étiquettes")
                }
            }
            .tint(Theme.ink)
            .navigationTitle("Classer la pièce")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        // On repart de la pièce à jour, pour ne pas écraser une autre modification.
                        var updated = store.item(id: item.id) ?? draft
                        updated.isFavorite = draft.isFavorite
                        updated.seasons = draft.seasons
                        updated.occasions = draft.occasions
                        updated.tagIDs = draft.tagIDs.filter { id in store.tags.contains { $0.id == id } }
                        store.update(updated)
                        dismiss()
                    }
                }
            }
        }
    }

    private func membership<Value: Hashable>(_ value: Value, in keyPath: WritableKeyPath<Item, Set<Value>>) -> Binding<Bool> {
        Binding(
            get: { draft[keyPath: keyPath].contains(value) },
            set: { isOn in
                if isOn {
                    draft[keyPath: keyPath].insert(value)
                } else {
                    draft[keyPath: keyPath].remove(value)
                }
            }
        )
    }
}

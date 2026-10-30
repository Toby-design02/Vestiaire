import PhotosUI
import SwiftUI

/// « Mes outfits » : l'agent qui compose une tenue à partir de mon dressing,
/// puis l'historique de toutes les tenues qu'il m'a proposées.
struct MyOutfitsSection: View {
    @Environment(WardrobeStore.self) private var store
    let onOpen: (GeneratedOutfit) -> Void

    @State private var request = OutfitRequest()
    @State private var isTryingOn = false
    @State private var tryOnText = ""
    @State private var tryOnPhoto: PhotosPickerItem?
    @State private var tryOnPhotoData: Data?
    @State private var isGenerating = false

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            generator
            history
        }
    }

    // MARK: - Paramètres

    private var generator: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ma tenue du jour")
                    .font(Theme.title(32))
                Text("Choisis tes envies, l'agent compose avec ce que tu as.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            parameter("Pièces à porter") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.activeItems) { item in
                            let isSelected = request.requiredIDs.contains(item.id)
                            Button {
                                if isSelected {
                                    request.requiredIDs.remove(item.id)
                                } else {
                                    request.requiredIDs.insert(item.id)
                                }
                            } label: {
                                ProductImage(item: item)
                                    .frame(width: 72)
                                    .overlay(Rectangle().stroke(isSelected ? Theme.ink : .clear, lineWidth: 1.5))
                                    .overlay(alignment: .topTrailing) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Theme.paper)
                                                .frame(width: 18, height: 18)
                                                .background(Theme.ink)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            parameter("Météo") {
                Toggle(isOn: $request.useWeather) {
                    Text(WardrobeStore.weatherToday.label)
                        .font(.system(size: 14))
                }
                .tint(Theme.ink)
            }

            parameter("Occasion") {
                pills(Occasion.allCases, selection: $request.occasion) { $0.label }
            }

            parameter("Style") {
                pills(StylePreset.allCases, selection: $request.style) { $0.label }
            }

            tryOnParameter

            Button {
                generate()
            } label: {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView().tint(Theme.paper)
                        Text("Composition en cours")
                    } else {
                        Text("Composer ma tenue")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isGenerating)
        }
        .padding(.horizontal, 16)
    }

    /// Essayer virtuellement une pièce qu'on n'a pas encore.
    private var tryOnParameter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { isTryingOn.toggle() }
            } label: {
                HStack {
                    Text("ET SI J'ACHETAIS…")
                        .font(Theme.label)
                        .tracking(1.5)
                    Spacer()
                    Image(systemName: isTryingOn ? "minus" : "plus")
                        .font(.system(size: 12, weight: .light))
                }
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isTryingOn {
                Text("Décris la pièce ou importe sa photo : elle sera ajoutée à la tenue.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                TextField("Ex : casquette Jacquemus beige", text: $tryOnText)
                    .font(.system(size: 15))
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
                HStack(spacing: 12) {
                    PhotosPicker(selection: $tryOnPhoto, matching: .images) {
                        Label(tryOnPhotoData == nil ? "Importer une photo" : "Changer la photo", systemImage: "photo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    if let data = tryOnPhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipped()
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .onChange(of: tryOnPhoto) { _, newValue in
            Task {
                tryOnPhotoData = try? await newValue?.loadTransferable(type: Data.self)
            }
        }
    }

    private func parameter<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            content()
        }
    }

    private func pills<Option: Identifiable & Hashable>(_ options: [Option], selection: Binding<Option>, label: @escaping (Option) -> String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    OptionPill(title: label(option), isSelected: selection.wrappedValue == option) {
                        selection.wrappedValue = option
                    }
                }
            }
            .padding(1)
        }
    }

    private func generate() {
        var finalRequest = request
        let text = tryOnText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTryingOn, !text.isEmpty || tryOnPhotoData != nil {
            finalRequest.tryOn = TryOnPiece(description: text.isEmpty ? "la pièce de ta photo" : text, photo: tryOnPhotoData)
        }
        isGenerating = true
        Task {
            // Le temps que le pipeline mettra à générer l'image.
            try? await Task.sleep(for: .seconds(1.4))
            let outfit = store.generateOutfit(finalRequest)
            store.saveGenerated(outfit)
            isGenerating = false
            onOpen(outfit)
        }
    }

    // MARK: - Historique

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Historique")
                Spacer()
                Text("\(store.generatedOutfits.count) tenues proposées")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(store.generatedOutfits) { outfit in
                    Button {
                        onOpen(outfit)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            GeneratedOutfitImage(outfit: outfit)
                                .padding(.bottom, 8)
                            Group {
                                Text(outfit.date.shortFR.uppercased())
                                    .font(Theme.label)
                                    .tracking(1.2)
                                Text("\(outfit.occasion.label) · \(outfit.style.label)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                if let tryOn = outfit.tryOn {
                                    Text("Avec : \(tryOn.description)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// L'image d'une tenue proposée : la mise en scène générée si elle existe,
/// sinon les pièces posées sur un fond de studio.
struct GeneratedOutfitImage: View {
    @Environment(WardrobeStore.self) private var store
    let outfit: GeneratedOutfit

    var body: some View {
        if let name = outfit.renderName {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            let pieces = outfit.itemIDs.compactMap { store.item(id: $0) } + (outfit.tryOn.map { [$0.item] } ?? [])
            OutfitFlatLay(pieces: pieces, backdropHex: "F3F2EF")
                .overlay(alignment: .bottomTrailing) {
                    if let data = outfit.tryOn?.photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipped()
                            .overlay(Rectangle().stroke(Theme.paper, lineWidth: 2))
                            .padding(10)
                    }
                }
        }
    }
}

/// Le détail d'une tenue proposée : l'image, pourquoi ces pièces, et les pièces.
struct GeneratedOutfitView: View {
    @Environment(WardrobeStore.self) private var store
    let outfit: GeneratedOutfit

    var body: some View {
        let pieces = outfit.itemIDs.compactMap { store.item(id: $0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GeneratedOutfitImage(outfit: outfit)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel([outfit.date.shortFR, outfit.occasion.label, outfit.style.label].joined(separator: " · "))
                    Text(outfit.tryOn == nil ? "Ta tenue" : "Ta tenue, avec ta future pièce")
                        .font(Theme.title(30))
                    if let weather = outfit.weather {
                        Text(weather)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    if outfit.renderName == nil {
                        Text("La photo mise en scène de cette tenue arrivera avec la génération d'images.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Pourquoi cette tenue")
                        .padding(.bottom, 8)
                    ForEach(outfit.reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.line).frame(height: 0.5)
                            }
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Les pièces")
                        .padding(.bottom, 8)
                    if let tryOn = outfit.tryOn {
                        pieceRow(tryOn.item, note: "À acheter")
                    }
                    ForEach(pieces) { piece in
                        NavigationLink(value: piece.id) {
                            pieceRow(piece, note: portsLabel(store.wearCount(of: piece)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pieceRow(_ piece: Item, note: String) -> some View {
        HStack(spacing: 14) {
            ProductImage(item: piece)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.brand?.name.uppercased() ?? "SANS MARQUE")
                    .font(Theme.label)
                    .tracking(1.2)
                Text("\(piece.type) \(piece.colors.first?.lowercased() ?? "")")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(note)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(note == "À acheter" ? Theme.accent : Theme.muted)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
    }
}

import SwiftUI

/// Le Wrapped : le format de Spotify (une story plein écran qui défile toute seule),
/// avec la direction artistique de la boutique. Puis les chiffres clés et les cartes à partager.
struct WrappedView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var period: StatsPeriod = .year
    @State private var sharedCard: StoryCardKind?
    @State private var isPlaying = false

    var body: some View {
        let stats = store.stats(for: period)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    if stats.photographedDays == 0 {
                        Text("Pas encore assez de photos sur cette période.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 16)
                    } else {
                        hero(stats)
                        keyFigures(stats)
                        cards(stats)
                        dormantItems
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sharedCard) { kind in
                StorySharePreview(card: StoryCard(kind: kind, stats: stats))
            }
            .fullScreenCover(isPresented: $isPlaying) {
                StoryPlayer(stats: stats)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            Text("WRAPPED")
                .font(.system(size: 15, weight: .semibold))
                .tracking(6)
            HStack(spacing: 24) {
                ForEach(StatsPeriod.allCases) { option in
                    Chip(title: option.label, isSelected: period == option) {
                        withAnimation(.snappy) { period = option }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Le grand bloc qui lance la story.
    private func hero(_ stats: WardrobeStats) -> some View {
        Button {
            isPlaying = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                Theme.ink
                if let favorite = stats.favorite {
                    ProductImage(item: favorite.item, showsBackground: false)
                        .frame(width: 210, height: 210)
                        .opacity(0.9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 24)
                        .padding(.trailing, 8)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("TON ANNÉE EN VÊTEMENTS")
                        .font(Theme.label)
                        .tracking(2)
                    Text("Ton Wrapped\n\(stats.period.cardLabel())")
                        .font(Theme.title(44))
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("VOIR MON RÉCAP")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(Theme.bone)
                    .foregroundStyle(Theme.ink)
                }
                .foregroundStyle(Theme.bone)
                .padding(22)
            }
            .frame(height: 380)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func keyFigures(_ stats: WardrobeStats) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 8) {
            StatTile(value: "\(stats.itemCount)", label: "Pièces")
            StatTile(value: "\(stats.photographedDays)", label: "Jours en photo")
            StatTile(value: stats.wornShare.percent, label: "Du dressing porté")
            StatTile(value: "\(stats.dormantCount)", label: "Pièces dormantes")
        }
        .padding(.horizontal, 16)
    }

    private func cards(_ stats: WardrobeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("À partager en story")
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StoryCardKind.available(for: stats)) { kind in
                        Button {
                            sharedCard = kind
                        } label: {
                            StoryCard(kind: kind, stats: stats)
                                .scaleEffect(0.45)
                                .frame(width: StoryCard.size.width * 0.45, height: StoryCard.size.height * 0.45)
                                .overlay(Rectangle().stroke(Theme.line, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var dormantItems: some View {
        let dormant = store.activeItems.filter { store.isDormant($0) }
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Elles dorment depuis 3 mois")
                .padding(.bottom, 8)
            if dormant.isEmpty {
                Text("Tout ton dressing est porté. Bravo.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(dormant) { item in
                    HStack(spacing: 12) {
                        ProductImage(item: item)
                            .frame(width: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                                .font(.system(size: 14))
                            Text(store.lastWorn(item).map { "Dernier port : \($0.shortFR)" } ?? "Jamais portée")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(item.resaleValue.map { "≈ \($0.euros)" } ?? "À porter")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.line).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// La story plein écran : barres de progression en haut, défilement automatique,
/// toucher à droite pour avancer, à gauche pour revenir.
struct StoryPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let stats: WardrobeStats

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var sharedCard: StoryCardKind?

    private static let duration: Double = 5

    private var kinds: [StoryCardKind] {
        StoryCardKind.available(for: stats)
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / StoryCard.size.width, geometry.size.height / StoryCard.size.height)
            ZStack(alignment: .top) {
                Theme.ink.ignoresSafeArea()

                StoryCard(kind: kinds[index], stats: stats)
                    .scaleEffect(scale)
                    .frame(width: StoryCard.size.width * scale, height: StoryCard.size.height * scale)
                    .id(kinds[index])
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        HStack(spacing: 0) {
                            Color.clear.contentShape(Rectangle()).onTapGesture { go(-1) }
                            Color.clear.contentShape(Rectangle()).onTapGesture { go(1) }
                        }
                    }

                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(kinds.indices, id: \.self) { position in
                            GeometryReader { bar in
                                Capsule().fill(.white.opacity(0.3))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(.white)
                                            .frame(width: bar.size.width * fill(for: position))
                                    }
                            }
                            .frame(height: 3)
                        }
                    }
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.black.opacity(0.45)))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                Button {
                    sharedCard = kinds[index]
                } label: {
                    Label("PARTAGER", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.4)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Theme.bone)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.bottom, 16)
            }
        }
        .statusBarHidden()
        .task(id: index) {
            progress = 0
            let steps = 50
            for _ in 0..<steps {
                try? await Task.sleep(for: .seconds(Self.duration / Double(steps)))
                if Task.isCancelled || sharedCard != nil { return }
                progress += 1 / Double(steps)
            }
            go(1)
        }
        .sheet(item: $sharedCard) { kind in
            StorySharePreview(card: StoryCard(kind: kind, stats: stats))
        }
    }

    private func fill(for position: Int) -> Double {
        if position < index { return 1 }
        if position > index { return 0 }
        return progress
    }

    private func go(_ step: Int) {
        let next = index + step
        if next >= kinds.count {
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                index = max(0, next)
            }
        }
    }
}

/// Aperçu en grand d'une carte, rendue en image pour le partage.
struct StorySharePreview: View {
    @Environment(\.dismiss) private var dismiss
    let card: StoryCard
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                card
                    .frame(width: StoryCard.size.width, height: StoryCard.size.height)
                    .scaleEffect(0.75)
                    .frame(width: StoryCard.size.width * 0.75, height: StoryCard.size.height * 0.75)
                    .overlay(Rectangle().stroke(Theme.line, lineWidth: 0.5))

                if let image {
                    ShareLink(item: image, preview: SharePreview("Mon Wrapped Vestiaire", image: image)) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                render()
            }
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: card.frame(width: StoryCard.size.width, height: StoryCard.size.height))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }
}

#Preview {
    WrappedView()
        .environment(WardrobeStore.sample())
}

import Photos
import SwiftUI

/// Le moment waouh : récompense en moins de deux minutes, sans rien saisir.
struct OnboardingFlow: View {
    let onFinish: () -> Void
    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, selfie, photos, reveal, miniWrapped, swipe, invite
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: WelcomeStep(onNext: next)
                case .selfie: SelfieStep(onNext: next)
                case .photos: PhotosStep(onNext: next)
                case .reveal: RevealStep(onNext: next)
                case .miniWrapped: MiniWrappedStep(onNext: next)
                case .swipe: SwipeStep(onNext: next)
                case .invite: InviteStep(onNext: next)
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func next() {
        if let following = Step(rawValue: step.rawValue + 1) {
            step = following
        } else {
            onFinish()
        }
    }
}

/// Mise en page commune aux étapes.
private struct OnboardingPage<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(eyebrow)
            Text(title)
                .font(Theme.title(34))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 1. Accueil

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Vestiaire",
            title: "Ton dressing, scanné en 2 minutes.",
            subtitle: "Ta personnalité, en chiffres. Aucune saisie : un selfie, ta galerie, et l'IA fait le reste."
        ) {
            Spacer()
            Image(systemName: "hanger")
                .font(.system(size: 120, weight: .ultraLight))
                .frame(maxWidth: .infinity)
            Spacer()
            Button("Commencer", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

// MARK: - 2. Selfie de référence

private struct SelfieStep: View {
    let onNext: () -> Void
    @State private var isTaken = false

    var body: some View {
        OnboardingPage(
            eyebrow: "Étape 1 sur 3",
            title: "Un selfie pour te reconnaître.",
            subtitle: "Il reste sur ton iPhone et sert uniquement à te retrouver sur tes photos. Aucune donnée faciale n'est envoyée."
        ) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.card)
                    .frame(width: 220, height: 220)
                Image(systemName: isTaken ? "checkmark" : "person.crop.circle")
                    .font(.system(size: isTaken ? 64 : 110, weight: .thin))
                    .foregroundStyle(isTaken ? Theme.accent : Theme.muted)
            }
            .frame(maxWidth: .infinity)
            Spacer()
            // Simulé pour le prototype : la vraie caméra viendra avec le pipeline.
            if isTaken {
                Button("Continuer", action: onNext)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Prendre mon selfie") {
                    withAnimation(.spring) { isTaken = true }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - 3. Accès à la galerie

private struct PhotosStep: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Étape 2 sur 3",
            title: "On cherche tes vêtements dans tes photos.",
            subtitle: "L'analyse se fait sur ton iPhone."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                promise("iphone", "Tes photos ne quittent pas ton téléphone.")
                promise("eye.slash", "Papiers d'identité, captures et photos médicales sont exclus automatiquement.")
                promise("person.crop.rectangle", "Tes amis sur les photos ne sont jamais analysés.")
            }
            .padding(.top, 24)
            Spacer()
            Button("Autoriser l'accès à Photos") {
                Task {
                    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    onNext()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Choisir 30 photos de moi à la place", action: onNext)
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func promise(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 4. Révélation progressive

private struct RevealStep: View {
    @Environment(WardrobeStore.self) private var store
    let onNext: () -> Void
    @State private var shown = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        let items = store.activeItems
        let isDone = shown >= items.count
        OnboardingPage(
            eyebrow: isDone ? "Analyse terminée" : "Analyse en cours",
            title: "\(shown) pièces trouvées",
            subtitle: isDone ? "Ta garde-robe est prête." : "On parcourt tes photos depuis 2023…"
        ) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(items.prefix(shown)) { item in
                        ProductImage(item: item)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
            }
            Button("Voir mon récap", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
                .opacity(isDone ? 1 : 0.3)
                .disabled(!isDone)
        }
        .task {
            for index in 0..<items.count {
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.spring(duration: 0.4)) { shown = index + 1 }
            }
        }
    }
}

// MARK: - 5. Premier mini-Wrapped

private struct MiniWrappedStep: View {
    @Environment(WardrobeStore.self) private var store
    let onNext: () -> Void

    var body: some View {
        let stats = store.stats(for: .all)
        OnboardingPage(
            eyebrow: "Ton premier récap",
            title: "Voilà qui tu es, côté style.",
            subtitle: "Calculé à partir de \(stats.photographedDays) jours où tu es en photo."
        ) {
            VStack(spacing: 1) {
                if let favorite = stats.favorite {
                    HStack(spacing: 16) {
                        ProductImage(item: favorite.item)
                            .frame(width: 70)
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel("Pièce favorite")
                            Text("\(favorite.item.type) \(favorite.item.colors.first?.lowercased() ?? "")")
                                .font(Theme.title(20))
                            Text("Portée \(favorite.wears) fois")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Theme.card)
                }
                if let color = stats.topColor {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(hex: color.hex))
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel("Couleur dominante")
                            Text(color.name)
                                .font(Theme.title(20))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Theme.card)
                }
                StatTile(value: "\(stats.itemCount)", label: "Pièces dans ton dressing")
            }
            .padding(.top, 16)
            Spacer()
            Button("Vérifier mes pièces", action: onNext)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

// MARK: - 6. Validation en swipe

private struct SwipeStep: View {
    @Environment(WardrobeStore.self) private var store
    let onNext: () -> Void

    @State private var queue: [Item] = []
    @State private var offset: CGSize = .zero
    @State private var didLoad = false

    private enum Decision {
        case mine, notMine, gone
    }

    var body: some View {
        OnboardingPage(
            eyebrow: "Validation",
            title: "C'est bien à toi ?",
            subtitle: "Glisse à droite si c'est à toi, à gauche sinon. Chaque réponse rend l'analyse plus précise."
        ) {
            ZStack {
                if let item = queue.first {
                    card(item)
                        .offset(offset)
                        .rotationEffect(.degrees(offset.width / 20))
                        .gesture(
                            DragGesture()
                                .onChanged { offset = $0.translation }
                                .onEnded { value in
                                    if value.translation.width > 120 {
                                        decide(.mine)
                                    } else if value.translation.width < -120 {
                                        decide(.notMine)
                                    } else {
                                        withAnimation(.spring) { offset = .zero }
                                    }
                                }
                        )
                        .id(item.id)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 56, weight: .thin))
                            .foregroundStyle(Theme.accent)
                        Text("Merci, c'est noté.")
                            .font(Theme.title(22))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if queue.isEmpty {
                Button("Continuer", action: onNext)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: 8) {
                    Button("Pas à moi") { decide(.notMine) }
                    Button("Je ne l'ai plus") { decide(.gone) }
                    Button("C'est à moi") { decide(.mine) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .font(.footnote)
                Button("Passer", action: onNext)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            queue = Array(store.activeItems.prefix(6))
        }
    }

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductImage(item: item)
                .frame(height: 300)
            Text(item.brand?.name.uppercased() ?? "MARQUE INCONNUE")
                .font(Theme.label)
                .tracking(1.2)
            Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                .font(Theme.title(20))
        }
        .padding(16)
        .background(.white)
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }

    private func decide(_ decision: Decision) {
        guard let item = queue.first else { return }
        switch decision {
        case .mine: break
        case .notMine: store.delete(item)
        case .gone: store.setStatus(.donated, for: item)
        }
        withAnimation(.spring) {
            queue.removeFirst()
            offset = .zero
        }
    }
}

// MARK: - 7. Invitation d'un ami

private struct InviteStep: View {
    @Environment(WardrobeStore.self) private var store
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "Étape 3 sur 3",
            title: "Invite un ami.",
            subtitle: "Le lien vous connecte directement : pas de liste d'attente. Vous pourrez comparer vos dressings et partager vos tenues."
        ) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 100, weight: .ultraLight))
                .frame(maxWidth: .infinity)
            Spacer()
            ShareLink(
                item: store.inviteURL,
                message: Text("Je viens de scanner mon dressing avec Vestiaire. Rejoins-moi :")
            ) {
                Text("Inviter un ami")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Entrer dans mon vestiaire", action: onNext)
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}

#Preview {
    OnboardingFlow {}
        .environment(WardrobeStore.sample())
}

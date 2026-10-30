import SwiftUI

/// Le profil d'un autre utilisateur : son vestiaire s'il est public, sinon une demande d'ami.
struct DiscoverProfileView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let profile: DiscoverProfile

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Avatar(name: profile.author.name, hex: profile.author.hex, size: 76)
                        Text(profile.author.name)
                            .font(Theme.title(32))
                        Text([profile.author.handle, profile.author.followers.map(followersLabel)].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        Text(profile.style.uppercased())
                            .font(Theme.label)
                            .tracking(1.5)
                    }
                    .padding(.top, 12)

                    if profile.isPublic {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("Vestiaire · \(profile.pieces.count) pièces")
                                .padding(.horizontal, 16)
                            LazyVGrid(columns: columns, spacing: 28) {
                                ForEach(profile.pieces) { piece in
                                    PublicPieceCell(piece: piece)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "lock")
                                .font(.system(size: 28, weight: .light))
                            Text("Vestiaire privé")
                                .font(Theme.title(24))
                            Text("\(profile.author.name) partage son vestiaire avec ses amis uniquement.")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                            let requested = store.friendRequests.contains(profile.id)
                            Button(requested ? "Demande envoyée" : "Demander en ami") {
                                store.toggleFriendRequest(profile)
                            }
                            .buttonStyle(requested ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
                            .padding(.top, 6)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

struct PublicPieceCell: View {
    let piece: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProductImage(item: piece)
                .padding(.bottom, 8)
            Group {
                Text(piece.brand?.name.uppercased() ?? "SANS MARQUE")
                    .font(Theme.label)
                    .tracking(1.2)
                Text("\(piece.type) \(piece.colors.first?.lowercased() ?? "")")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                if piece.openToOffers || piece.openToSwap {
                    Text([piece.openToOffers ? "Offres" : nil, piece.openToSwap ? "Échange" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.accent)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
        }
    }
}

/// Une tenue tendance en grand, avec l'accès au vestiaire de son auteur.
struct TrendingOutfitView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trend: TrendingOutfit
    @State private var openedProfile: DiscoverProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OutfitFlatLay(pieces: trend.pieces, backdropHex: trend.backdropHex)

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel("\(trend.likes.formatted()) j'aime")
                        Text(trend.title)
                            .font(Theme.title(30))
                    }
                    .padding(.horizontal, 20)

                    if let profile = store.profile(id: trend.profileID) {
                        HStack(spacing: 12) {
                            Avatar(name: profile.author.name, hex: profile.author.hex, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.author.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(profile.isPublic ? "Vestiaire public" : "Vestiaire privé")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Button(profile.isPublic ? "Son dressing" : (store.friendRequests.contains(profile.id) ? "Demande envoyée" : "Demander en ami")) {
                                if profile.isPublic {
                                    openedProfile = profile
                                } else {
                                    store.toggleFriendRequest(profile)
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
                            .foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel("Les pièces")
                            .padding(.bottom, 8)
                        ForEach(trend.pieces) { piece in
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
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.line).frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $openedProfile) { profile in
                DiscoverProfileView(profile: profile)
            }
        }
    }
}

/// Une pièce de seconde main : faire une offre ou proposer un échange.
struct ListingView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let listing: Listing

    @State private var amount = ""
    @State private var isChoosingSwap = false

    var body: some View {
        let seller = store.profile(id: listing.profileID)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProductImage(item: listing.item, aspect: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(listing.item.brand?.name.uppercased() ?? "SANS MARQUE")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(2)
                        Text("\(listing.item.type) \(listing.item.colors.first?.lowercased() ?? "")")
                            .font(Theme.title(28))
                        Text([listing.item.openToOffers ? listing.price.euros : nil, "Taille \(listing.size)", listing.condition].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 14))
                        if let paid = listing.item.pricePaid {
                            Text("Payé \(paid.euros) neuf")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 20)

                    if let seller {
                        HStack(spacing: 12) {
                            Avatar(name: seller.author.name, hex: seller.author.hex, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seller.author.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Portée dans ses OOTD")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if let sent = store.offers[listing.id] {
                        confirmation(sent)
                            .padding(.horizontal, 20)
                    } else {
                        actions
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                amount = String(Int((listing.price * 0.9).rounded()))
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            if listing.item.openToOffers {
                SectionLabel("Ton offre")
                HStack {
                    TextField("Montant", text: $amount)
                        .keyboardType(.numberPad)
                        .font(Theme.title(30))
                    Text("€")
                        .font(Theme.title(30))
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
                Button("Envoyer l'offre") {
                    if let value = Double(amount) {
                        store.offers[listing.id] = .price(value)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(Double(amount) == nil)
            }
            if listing.item.openToSwap {
                Button(isChoosingSwap ? "Choisis la pièce à proposer" : "Proposer un échange") {
                    withAnimation(.snappy) { isChoosingSwap.toggle() }
                }
                .buttonStyle(SecondaryButtonStyle())
                if isChoosingSwap {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.activeItems) { item in
                                Button {
                                    store.offers[listing.id] = .swap(item.id)
                                } label: {
                                    ProductImage(item: item)
                                        .frame(width: 80)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func confirmation(_ offer: OfferKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Proposition envoyée")
                .font(Theme.title(24))
            switch offer {
            case .price(let value):
                Text("Ton offre de \(value.euros) a été envoyée. Tu seras prévenu de sa réponse.")
            case .swap(let id):
                Text("Tu proposes ton \(store.item(id: id)?.type.lowercased() ?? "article") en échange. Tu seras prévenu de sa réponse.")
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Permet de choisir un style de bouton selon l'état.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<Style: ButtonStyle>(_ style: Style) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

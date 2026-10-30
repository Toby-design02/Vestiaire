import SwiftUI

enum DiscoverSection: String, CaseIterable, Identifiable {
    case trending, forYou, secondHand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trending: "Tendances"
        case .forYou: "Pour toi"
        case .secondHand: "Seconde main"
        }
    }
}

/// Découvrir : les tenues et les vestiaires des autres, ce qui compléterait mon dressing,
/// et les pièces que d'autres acceptent de vendre ou d'échanger.
struct DiscoverView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var section: DiscoverSection = .trending
    @State private var query = ""
    @State private var openedProfile: DiscoverProfile?
    @State private var openedTrend: TrendingOutfit?
    @State private var openedListing: Listing?
    @State private var tryOnOutfit: GeneratedOutfit?

    private static let aspects: [CGFloat] = [3 / 4, 1, 2 / 3, 4 / 5, 5 / 6, 3 / 4]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    switch section {
                    case .trending: trending
                    case .forYou: forYou
                    case .secondHand: secondHand
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $openedProfile) { profile in
                DiscoverProfileView(profile: profile)
            }
            .sheet(item: $openedTrend) { trend in
                TrendingOutfitView(trend: trend)
            }
            .sheet(item: $openedListing) { listing in
                ListingView(listing: listing)
            }
            .sheet(item: $tryOnOutfit) { outfit in
                NavigationStack {
                    GeneratedOutfitView(outfit: outfit)
                        .navigationDestination(for: UUID.self) { id in
                            ItemDetailView(itemID: id)
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fermer") { tryOnOutfit = nil }
                            }
                        }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            Text("DÉCOUVRIR")
                .font(.system(size: 15, weight: .semibold))
                .tracking(6)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Theme.muted)
                TextField("Une pièce, une marque, une personne", text: $query)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 24) {
                ForEach(DiscoverSection.allCases) { option in
                    Button {
                        withAnimation(.snappy) { section = option }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 15, weight: section == option ? .semibold : .regular))
                            .foregroundStyle(section == option ? Theme.ink : Theme.muted)
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.ink).frame(height: 1).opacity(section == option ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func matches(_ item: Item) -> Bool {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return true }
        return [item.type, item.brand?.name ?? "", item.colors.joined(separator: " ")].joined(separator: " ").lowercased().contains(text)
    }

    private func matches(_ profile: DiscoverProfile) -> Bool {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return true }
        return "\(profile.author.name) \(profile.author.handle) \(profile.style)".lowercased().contains(text)
            || profile.pieces.contains(where: matches)
    }

    // MARK: - Tendances

    private var trending: some View {
        let profiles = store.profiles.filter(matches)
        let trends = store.trending.filter { trend in
            query.isEmpty || trend.pieces.contains(where: matches) || store.profile(id: trend.profileID).map(matches) == true
        }
        return VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Vestiaires à découvrir")
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(profiles) { profile in
                            Button {
                                openedProfile = profile
                            } label: {
                                profileBubble(profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Les tenues du moment")
                    .padding(.horizontal, 16)
                HStack(alignment: .top, spacing: 8) {
                    trendColumn(trends, parity: 0)
                    trendColumn(trends, parity: 1)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func profileBubble(_ profile: DiscoverProfile) -> some View {
        VStack(spacing: 6) {
            Avatar(name: profile.author.name, hex: profile.author.hex, size: 64)
                .overlay(alignment: .bottomTrailing) {
                    if !profile.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 20, height: 20)
                            .background(Theme.ink)
                            .clipShape(Circle())
                    }
                }
            Text(profile.author.name)
                .font(.system(size: 13, weight: .semibold))
            Text(profile.author.followers.map(followersLabel) ?? (profile.author.viaFriend.map { "Ami·e de \($0)" } ?? ""))
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 92)
        .lineLimit(1)
    }

    private func trendColumn(_ trends: [TrendingOutfit], parity: Int) -> some View {
        LazyVStack(spacing: 18) {
            ForEach(Array(trends.enumerated()).filter { $0.offset % 2 == parity }, id: \.element.id) { index, trend in
                Button {
                    openedTrend = trend
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        OutfitFlatLay(pieces: trend.pieces, backdropHex: trend.backdropHex, aspect: Self.aspects[index % Self.aspects.count])
                        if let profile = store.profile(id: trend.profileID) {
                            HStack(spacing: 6) {
                                Avatar(name: profile.author.name, hex: profile.author.hex, size: 20)
                                Text(profile.author.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "heart")
                                    .font(.system(size: 11))
                                Text(trend.likes.formatted())
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pour toi

    private var forYou: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text("Ce qui compléterait ton dressing, d'après ce que tu portes vraiment.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 16)

            ForEach(store.recommendations.filter { matches($0.item) }) { recommendation in
                VStack(alignment: .leading, spacing: 14) {
                    Text(recommendation.headline)
                        .font(Theme.title(24))
                    HStack(alignment: .top, spacing: 14) {
                        ProductImage(item: recommendation.item)
                            .frame(width: 120)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(recommendation.item.brand?.name.uppercased() ?? recommendation.shop.uppercased())
                                .font(Theme.label)
                                .tracking(1.2)
                            Text("\(recommendation.item.type) \(recommendation.item.colors.first?.lowercased() ?? "")")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                            Text(recommendation.price.euros)
                                .font(.system(size: 14))
                            Text(recommendation.reason)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 6)
                        }
                    }
                    Button("L'essayer dans une tenue") {
                        let item = recommendation.item
                        var request = OutfitRequest()
                        request.tryOn = TryOnPiece(description: "\(item.type.lowercased()) \(item.brand?.name ?? "") \(item.colors.first?.lowercased() ?? "")")
                        let outfit = store.generateOutfit(request)
                        store.saveGenerated(outfit)
                        tryOnOutfit = outfit
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Seconde main

    private var secondHand: some View {
        let listings = store.listings.filter { matches($0.item) }
        let mineOpen = store.activeItems.filter { $0.openToOffers || $0.openToSwap }.count
        let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Des pièces de vrais dressings, que leurs propriétaires acceptent de vendre ou d'échanger.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                Text(mineOpen == 0
                     ? "Toi aussi : ouvre une pièce aux offres depuis sa fiche."
                     : "\(mineOpen) de tes pièces sont ouvertes aux offres.")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(listings) { listing in
                    Button {
                        openedListing = listing
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            ProductImage(item: listing.item)
                                .overlay(alignment: .topLeading) {
                                    HStack(spacing: 4) {
                                        if listing.item.openToOffers { badge("Offres") }
                                        if listing.item.openToSwap { badge("Échange") }
                                    }
                                    .padding(8)
                                }
                                .padding(.bottom, 8)
                            Group {
                                Text(listing.item.brand?.name.uppercased() ?? "SANS MARQUE")
                                    .font(Theme.label)
                                    .tracking(1.2)
                                Text(listing.item.type)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                Text(listing.item.openToOffers ? listing.price.euros : "Échange uniquement")
                                    .font(.system(size: 13))
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

    private func badge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.paper)
            .foregroundStyle(Theme.ink)
    }
}

#Preview {
    DiscoverView()
        .environment(WardrobeStore.sample())
}

import SwiftUI

enum WardrobeSort: String, CaseIterable, Identifiable {
    case mostWorn = "Plus portées"
    case recent = "Portées récemment"
    case dormant = "Dormantes"

    var id: String { rawValue }
}

enum WardrobeMode: String, CaseIterable, Identifiable {
    case dressing, outfits

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dressing: "Mon dressing"
        case .outfits: "Mes outfits"
        }
    }
}

/// Les écrans qu'on ouvre depuis le Vestiaire.
enum WardrobeRoute: Hashable {
    case archives, wishlist, stats
    case wish(UUID)
    case event(UUID)
    case packing(UUID)
}

/// Accueil : la garde-robe présentée comme une boutique en ligne,
/// et « Mes outfits » (tenues proposées, journal des tenues portées, agenda).
struct WardrobeView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var mode: WardrobeMode = .dressing
    @State private var filter = WardrobeFilter()
    @State private var sort: WardrobeSort = .mostWorn
    @State private var path = NavigationPath()
    @State private var isInFittingRoom = false
    @State private var isFiltering = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private var visibleItems: [Item] {
        let list = store.activeItems.filter(filter.matches)
        switch sort {
        case .mostWorn:
            return list.sorted { store.wearCount(of: $0) > store.wearCount(of: $1) }
        case .recent:
            return list.sorted { (store.lastWorn($0) ?? .distantPast) > (store.lastWorn($1) ?? .distantPast) }
        case .dormant:
            return list
                .filter { store.isDormant($0) }
                .sorted { (store.lastWorn($0) ?? .distantPast) < (store.lastWorn($1) ?? .distantPast) }
        }
    }

    var body: some View {
        let items = visibleItems
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    switch mode {
                    case .dressing:
                        dressing(items)
                    case .outfits:
                        MyOutfitsSection { outfit in
                            path.append(outfit)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
            .navigationDestination(for: GeneratedOutfit.self) { outfit in
                GeneratedOutfitView(outfit: outfit)
            }
            .navigationDestination(for: WardrobeRoute.self) { route in
                switch route {
                case .archives: ArchivesView()
                case .wishlist: WishlistView()
                case .stats: StatsDashboardView()
                case .wish(let id): WishDetailView(wishID: id)
                case .event(let id): EventDetailView(eventID: id)
                case .packing(let id): PackingListView(eventID: id)
                }
            }
            .sheet(isPresented: $isInFittingRoom) {
                FittingRoomView()
            }
            .sheet(isPresented: $isFiltering) {
                FilterSheet(filter: $filter)
            }
        }
    }

    @ViewBuilder
    private func dressing(_ items: [Item]) -> some View {
        tools
        if filter.isEmpty {
            fittingRoomEntry
            highlight
        }
        filters(count: items.count)
        LazyVGrid(columns: columns, spacing: 32) {
            ForEach(items) { item in
                NavigationLink(value: item.id) {
                    ItemCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }

        if items.isEmpty {
            VStack(spacing: 12) {
                Text(filter.isEmpty ? "Aucune pièce ici pour l'instant." : "Aucune pièce ne correspond à ces filtres.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                if !filter.isEmpty {
                    Button("Effacer les filtres") { filter = WardrobeFilter() }
                        .font(.system(size: 13))
                        .underline()
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    /// Les outils du dressing : filtres, envies, archives, statistiques.
    private var tools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    isFiltering = true
                } label: {
                    ToolLabel(title: filter.activeCount > 0 ? "Filtres · \(filter.activeCount)" : "Filtres", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                NavigationLink(value: WardrobeRoute.wishlist) {
                    ToolLabel(title: "Mes envies · \(store.consideredWishes.count)", systemImage: "bookmark")
                }
                .buttonStyle(.plain)
                NavigationLink(value: WardrobeRoute.stats) {
                    ToolLabel(title: "Statistiques", systemImage: "chart.bar")
                }
                .buttonStyle(.plain)
                NavigationLink(value: WardrobeRoute.archives) {
                    ToolLabel(title: "Archives · \(store.archivedItems.count)", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }

    /// « En cabine ? » : vérifier une pièce avant de l'acheter.
    private var fittingRoomEntry: some View {
        Button {
            isInFittingRoom = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera")
                    .font(.system(size: 18, weight: .light))
                VStack(alignment: .leading, spacing: 2) {
                    Text("EN CABINE D'ESSAYAGE ?")
                        .font(Theme.label)
                        .tracking(1.5)
                    Text("Vérifie si tu as déjà la même chose avant d'acheter.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .light))
            }
            .foregroundStyle(Theme.ink)
            .padding(16)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("VESTIAIRE")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(6)
                Text("\(store.activeItems.count) pièces · \(store.loggedDays()) jours de tenues enregistrés")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 28) {
                ForEach(WardrobeMode.allCases) { option in
                    Button {
                        withAnimation(.snappy) { mode = option }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 15, weight: mode == option ? .semibold : .regular))
                            .foregroundStyle(mode == option ? Theme.ink : Theme.muted)
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.ink).frame(height: 1).opacity(mode == option ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    /// Encart éditorial : la pièce la plus portée du mois.
    @ViewBuilder
    private var highlight: some View {
        if let favorite = store.stats(for: .month).favorite {
            NavigationLink(value: favorite.item.id) {
                VStack(alignment: .leading, spacing: 0) {
                    ProductImage(item: favorite.item, aspect: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LA PIÈCE DU MOIS")
                            .font(Theme.label)
                            .tracking(2)
                        Text("\(favorite.item.type) \(favorite.item.colors.first?.lowercased() ?? "")")
                            .font(Theme.title(30))
                        Text("\(portsLabel(favorite.wears)) ce mois-ci\(favorite.item.brand.map { " · \($0.name)" } ?? "")")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom], 20)
                }
                .background(Theme.card)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 28)
        }
    }

    private func filters(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    Chip(title: "Tout", isSelected: filter.categories.isEmpty) { filter.categories = [] }
                    ForEach(ClothingCategory.allCases) { option in
                        Chip(title: option.label, isSelected: filter.categories.contains(option)) { filter.categories = [option] }
                    }
                }
                .padding(.horizontal, 16)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 0.5)
            }

            HStack {
                Text(count == 1 ? "1 article" : "\(count) articles")
                    .foregroundStyle(Theme.muted)
                if !filter.isEmpty {
                    Button("Effacer les filtres") { filter = WardrobeFilter() }
                        .underline()
                        .foregroundStyle(Theme.ink)
                        .padding(.leading, 8)
                }
                Spacer()
                Menu {
                    Picker("Trier", selection: $sort) {
                        ForEach(WardrobeSort.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Trier : \(sort.rawValue)")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

struct ItemCard: View {
    @Environment(WardrobeStore.self) private var store
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProductImage(item: item)
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                            .padding(10)
                            .accessibilityLabel("Favori")
                    }
                }
                .padding(.bottom, 8)
            Group {
                Text(item.brand?.name.uppercased() ?? "MARQUE À COMPLÉTER")
                    .font(Theme.label)
                    .tracking(1.2)
                    .foregroundStyle(item.brand == nil ? Theme.accent : Theme.ink)
                Text("\(item.type) \(item.colors.first?.lowercased() ?? "")")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                Text(subtitle)
                    .font(.system(size: 13))
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
        }
    }

    private var subtitle: String {
        let wears = store.wearCount(of: item)
        if let cost = store.costPerWear(of: item) {
            return "\(portsLabel(wears)) · \(cost.euros) / port"
        }
        return wears == 0 ? "Aucun port" : portsLabel(wears)
    }
}

#Preview {
    WardrobeView()
        .environment(WardrobeStore.sample())
}

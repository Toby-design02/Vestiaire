import SwiftUI

/// Les cinq onglets de la barre du bas.
struct RootTabView: View {
    enum Tab {
        case wardrobe, discover, feed, wrapped, profile
    }

    @State private var tab: Tab = .wardrobe

    var body: some View {
        TabView(selection: $tab) {
            WardrobeView()
                .tabItem { Label("Vestiaire", systemImage: "hanger") }
                .tag(Tab.wardrobe)
            DiscoverView()
                .tabItem { Label("Découvrir", systemImage: "magnifyingglass") }
                .tag(Tab.discover)
            FeedView()
                .tabItem { Label("OOTD", systemImage: "camera") }
                .tag(Tab.feed)
            WrappedView()
                .tabItem { Label("Wrapped", systemImage: "chart.bar") }
                .tag(Tab.wrapped)
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        // Le feed est en mode nuit, façon BeReal ; le reste en mode boutique (clair).
        .preferredColorScheme(tab == .feed ? .dark : .light)
    }
}

#Preview {
    RootTabView()
        .environment(WardrobeStore.sample())
}

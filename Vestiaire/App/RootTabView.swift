import SwiftUI

/// Les quatre onglets de la barre du bas.
/// Le journal des tenues portées et l'agenda sont dans Vestiaire → Mes outfits.
struct RootTabView: View {
    enum Tab {
        case wardrobe, discover, wrapped, profile
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
            WrappedView()
                .tabItem { Label("Wrapped", systemImage: "chart.bar") }
                .tag(Tab.wrapped)
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    RootTabView()
        .environment(WardrobeStore.sample())
}

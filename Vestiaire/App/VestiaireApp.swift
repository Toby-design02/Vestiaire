import SwiftUI

@main
struct VestiaireApp: App {
    @State private var store = WardrobeStore.sample()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingFlow {
                        hasCompletedOnboarding = true
                    }
                    .preferredColorScheme(.light)
                }
            }
            .environment(store)
            .tint(Theme.ink)
        }
    }
}

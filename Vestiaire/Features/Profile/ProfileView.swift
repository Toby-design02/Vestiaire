import SwiftUI

struct ProfileView: View {
    @Environment(WardrobeStore.self) private var store
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String(store.user.displayName.prefix(1)))
                            .font(Theme.title(24))
                            .frame(width: 56, height: 56)
                            .background(Theme.card)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.user.displayName)
                                .font(Theme.title(22))
                            Text("\(store.friends.count) amis · \(store.activeItems.count) pièces")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LabeledContent("Valeur de revente estimée", value: store.totalResaleValue.euros)
                    LabeledContent("Total payé", value: store.totalPaid.euros)
                } header: {
                    Text("Portefeuille")
                } footer: {
                    Text("Estimations à partir des prix de revente constatés. Bientôt : alertes « bon moment pour vendre » et annonces Vinted préremplies.")
                }

                Section {
                    Toggle("Vestiaire public", isOn: $store.user.isWardrobePublic)
                } header: {
                    Text("Visibilité")
                } footer: {
                    Text(store.user.isWardrobePublic
                         ? "Tout le monde peut voir les pièces de ton vestiaire."
                         : "Toi seul peux voir ton vestiaire.")
                }

                Section("Amis") {
                    ForEach(store.friends) { friend in
                        Text(friend.displayName)
                    }
                    ShareLink(item: store.inviteURL) {
                        Label("Inviter un ami", systemImage: "person.badge.plus")
                    }
                }

                Section("Confidentialité") {
                    Label("Tes photos ne quittent pas ton iPhone", systemImage: "iphone")
                    Label("Aucune donnée faciale sur nos serveurs", systemImage: "faceid")
                    Label("Documents et captures exclus automatiquement", systemImage: "eye.slash")
                }

                Section("Prototype") {
                    Button("Revoir l'onboarding") {
                        hasCompletedOnboarding = false
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Profil")
        }
    }
}

#Preview {
    ProfileView()
        .environment(WardrobeStore.sample())
}

import SwiftUI

/// Le vestiaire public d'un ami d'ami ou d'un créateur, présenté comme une boutique.
struct PublicWardrobeView: View {
    @Environment(\.dismiss) private var dismiss
    let author: FeedAuthor
    let posts: [FeedPost]

    private var pieces: [Item] {
        var seen = Set<String>()
        return posts.flatMap(\.pieces).filter { seen.insert("\($0.brand?.name ?? "")\($0.type)\($0.colorHex)").inserted }
    }

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 10) {
                        Avatar(name: author.name, hex: author.hex, size: 72)
                        Text(author.name)
                            .font(Theme.title(32))
                        Text([author.handle, author.followers.map(followersLabel)].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        if let via = author.viaFriend {
                            Text("Ami·e de \(via)")
                                .font(Theme.label)
                                .tracking(1.2)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Vestiaire · \(pieces.count) pièces")
                            .padding(.horizontal, 16)
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(pieces) { piece in
                                VStack(alignment: .leading, spacing: 4) {
                                    ProductImage(item: piece)
                                    Group {
                                        Text(piece.brand?.name.uppercased() ?? "SANS MARQUE")
                                            .font(Theme.label)
                                            .tracking(1.2)
                                        Text("\(piece.type) \(piece.colors.first?.lowercased() ?? "")")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.muted)
                                        if let price = piece.pricePaid {
                                            Text(price.euros)
                                                .font(.system(size: 13))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .lineLimit(1)
                                }
                            }
                        }
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
        .preferredColorScheme(.light)
    }
}

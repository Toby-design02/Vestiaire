import Foundation

extension WardrobeStore {
    static let myColorHex = "E5482D"

    var me: FeedAuthor {
        FeedAuthor(id: user.id, name: user.displayName, handle: "@\(user.displayName.lowercased())", hex: Self.myColorHex, isMe: true)
    }

    func posts(in circle: FeedCircle) -> [FeedPost] {
        feed.filter { $0.circle == circle && !$0.author.isMe }.sorted { $0.date > $1.date }
    }

    var myPostToday: FeedPost? {
        feed.first { $0.author.isMe && Calendar.current.isDateInToday($0.date) }
    }

    /// Dernière tenue portée : sert de point de départ pour composer l'OOTD.
    var lastOutfitItems: [Item] {
        guard let outfit = outfits.max(by: { $0.date < $1.date }) else { return [] }
        return outfit.itemIDs.compactMap { item(id: $0) }.filter { $0.status == .active }
    }

    /// Publier son OOTD compte aussi comme un port de chaque pièce.
    func publishOOTD(items: [Item], caption: String?, audience: Audience, now: Date = .now) {
        let late = Int(now.timeIntervalSince(ootdMoment) / 60) - 2
        let session = Session(date: now, context: .everyday)
        sessions.append(session)
        wearEvents += items.map { WearEvent(itemID: $0.id, sessionID: session.id, date: now) }
        outfits.append(Outfit(itemIDs: items.map(\.id), date: now, source: .ootd))
        feed.insert(
            FeedPost(
                author: me,
                circle: .friends,
                date: now,
                minutesLate: max(0, late),
                place: "Paris",
                caption: caption,
                pieces: items,
                backdropHex: "D9D3C7",
                audience: audience
            ),
            at: 0
        )
    }

    func toggleReaction(_ emoji: String, on post: FeedPost) {
        guard let index = feed.firstIndex(where: { $0.id == post.id }) else { return }
        if let existing = feed[index].reactions.firstIndex(where: { $0.authorName == user.displayName }) {
            let previous = feed[index].reactions.remove(at: existing)
            if previous.emoji == emoji { return }
        }
        feed[index].reactions.append(Reaction(authorName: user.displayName, hex: Self.myColorHex, emoji: emoji))
    }
}

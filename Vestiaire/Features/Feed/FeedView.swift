import SwiftUI

/// Le feed OOTD, façon BeReal : un moment par jour, 2 minutes pour poster sa tenue,
/// et le feed reste flouté tant qu'on n'a pas posté la sienne.
struct FeedView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var circle: FeedCircle = .friends
    @State private var isComposing = false
    @State private var openedWardrobe: FeedAuthor?
    @State private var isShowingMemories = false

    var body: some View {
        let isLocked = store.myPostToday == nil
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let mine = store.myPostToday {
                        Button {
                            isShowingMemories = true
                        } label: {
                            MyPostSummary(post: mine)
                        }
                        .buttonStyle(.plain)
                    } else {
                        OOTDPrompt(moment: store.ootdMoment) { isComposing = true }
                    }

                    ForEach(store.posts(in: circle)) { post in
                        FeedPostView(post: post, isLocked: isLocked) {
                            openedWardrobe = post.author
                        }
                    }

                    Text("C'est tout pour aujourd'hui.")
                        .font(.footnote)
                        .foregroundStyle(Theme.nightMuted)
                        .padding(.vertical, 24)
                }
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .background(Theme.night)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isComposing) {
                ComposeOOTDView()
            }
            .sheet(item: $openedWardrobe) { author in
                PublicWardrobeView(author: author, posts: store.feed.filter { $0.author.id == author.id })
            }
            .sheet(isPresented: $isShowingMemories) {
                MemoriesView()
            }
            .toolbarBackground(Theme.night, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                ShareLink(item: store.inviteURL) {
                    Image(systemName: "person.2")
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
                Text("Vestiaire.")
                    .font(Theme.wordmark(22))
                Spacer()
                // Comme sur BeReal : l'avatar ouvre mes souvenirs.
                Button {
                    isShowingMemories = true
                } label: {
                    Avatar(name: store.user.displayName, hex: WardrobeStore.myColorHex, size: 30)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.bone)

            HStack(spacing: 20) {
                ForEach(FeedCircle.allCases) { option in
                    Button {
                        withAnimation(.snappy) { circle = option }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 15, weight: circle == option ? .bold : .medium))
                            .foregroundStyle(circle == option ? Theme.bone : Theme.nightMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(Theme.night)
    }
}

/// « C'est l'heure de ton OOTD » avec le compte à rebours de 2 minutes.
private struct OOTDPrompt: View {
    let moment: Date
    let onPost: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(moment.addingTimeInterval(120).timeIntervalSince(context.date))
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                    Text(remaining > 0 ? "C'est l'heure de ton OOTD" : "Tu es en retard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                Text(remaining > 0 ? countdown(remaining) : "+\(countdown(-remaining))")
                    .font(Theme.display(64))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(Theme.bone)
                Text("Poste ta tenue du jour pour voir celles de tes amis.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.nightMuted)
                Button(action: onPost) {
                    Text("Poster mon OOTD")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.bone)
                        .foregroundStyle(Theme.night)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(20)
            .background(Theme.nightRaised)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
        }
    }

    private func countdown(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Mon OOTD du jour, en petit en haut du feed.
private struct MyPostSummary: View {
    let post: FeedPost

    var body: some View {
        VStack(spacing: 10) {
            PostImage(post: post)
                .frame(width: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Mon OOTD")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.bone)
            Text(post.minutesLate > 0 ? "Posté avec \(post.minutesLate) min de retard" : "Posté à l'heure · \(post.date.timeFR)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.nightMuted)
        }
        .padding(.top, 8)
    }
}

struct FeedPostView: View {
    @Environment(WardrobeStore.self) private var store
    let post: FeedPost
    let isLocked: Bool
    let onOpenWardrobe: () -> Void

    @State private var showsSelfieFirst = false
    @State private var isPickingReaction = false

    private static let emojis = ["🔥", "😍", "👏", "😂", "😮"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorLine
                .padding(.horizontal, 16)
            photo
                .padding(.horizontal, 10)
            if !isLocked {
                piecesRow
                if let caption = post.caption {
                    Text(caption)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.bone)
                        .padding(.horizontal, 16)
                }
                actions
                    .padding(.horizontal, 16)
            }
        }
    }

    private var authorLine: some View {
        HStack(spacing: 10) {
            Avatar(name: post.author.name, hex: post.author.hex)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.bone)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.nightMuted)
                    .lineLimit(1)
            }
            Spacer()
            if post.circle == .discovery {
                Button(action: onOpenWardrobe) {
                    Text("Son vestiaire")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Capsule().stroke(Theme.bone.opacity(0.5), lineWidth: 1))
                        .foregroundStyle(Theme.bone)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let via = post.author.viaFriend {
            parts.append("Ami·e de \(via)")
        }
        if let place = post.place {
            parts.append(place)
        }
        parts.append(post.date.relativeFR())
        if post.minutesLate > 0 {
            parts.append(post.minutesLate >= 60 ? "\(post.minutesLate / 60) h de retard" : "\(post.minutesLate) min de retard")
        }
        return parts.joined(separator: " · ")
    }

    private var photo: some View {
        ZStack(alignment: .topLeading) {
            mainView(selfie: showsSelfieFirst)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isLocked {
                mainView(selfie: !showsSelfieFirst)
                    .frame(width: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.night, lineWidth: 2))
                    .padding(12)
                    .onTapGesture {
                        withAnimation(.snappy) { showsSelfieFirst.toggle() }
                    }
            }
        }
        .blur(radius: isLocked ? 28 : 0)
        .overlay {
            if isLocked {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 26, weight: .semibold))
                    Text("Poste ton OOTD pour voir\ncelui de \(post.author.name)")
                        .font(.system(size: 15, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Theme.bone)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !isLocked, !post.reactions.isEmpty {
                reactionsStack
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func mainView(selfie: Bool) -> some View {
        if selfie {
            SelfiePlaceholder(author: post.author)
        } else {
            PostImage(post: post)
        }
    }

    /// Les réactions façon RealMoji : la pastille de l'ami avec son émoji.
    private var reactionsStack: some View {
        HStack(spacing: -8) {
            ForEach(post.reactions.prefix(5)) { reaction in
                Avatar(name: reaction.authorName, hex: reaction.hex, size: 34)
                    .overlay(Circle().stroke(Theme.night, lineWidth: 2))
                    .overlay(alignment: .bottomTrailing) {
                        Text(reaction.emoji)
                            .font(.system(size: 13))
                            .offset(x: 4, y: 4)
                    }
            }
        }
    }

    private var piecesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(post.pieces) { piece in
                    HStack(spacing: 8) {
                        ProductImage(item: piece, showsBackground: false)
                            .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(piece.brand?.name ?? "Sans marque")
                                .font(.system(size: 11, weight: .bold))
                            Text(piece.type)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.nightMuted)
                        }
                    }
                    .foregroundStyle(Theme.bone)
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .padding(.vertical, 6)
                    .background(Theme.nightRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var actions: some View {
        HStack(spacing: 18) {
            if isPickingReaction {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button(emoji) {
                        store.toggleReaction(emoji, on: post)
                        withAnimation(.snappy) { isPickingReaction = false }
                    }
                    .font(.system(size: 24))
                }
            } else {
                Button {
                    withAnimation(.snappy) { isPickingReaction = true }
                } label: {
                    Image(systemName: "face.smiling")
                }
                Label(post.commentCount == 0 ? "Commenter" : "\(post.commentCount) commentaires", systemImage: "bubble.left")
            }
            Spacer()
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Theme.nightMuted)
        .buttonStyle(.plain)
    }
}

/// L'image principale d'un post : la vraie photo si elle existe, sinon la tenue à plat.
struct PostImage: View {
    let post: FeedPost

    var body: some View {
        if let name = post.photoName {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            OutfitFlatLay(pieces: post.pieces, backdropHex: post.backdropHex)
        }
    }
}

/// En attendant les vrais selfies (qui restent sur l'iPhone de chacun).
struct SelfiePlaceholder: View {
    let author: FeedAuthor

    var body: some View {
        ZStack {
            Color(hex: author.hex)
            Color.black.opacity(0.25)
            Text(String(author.name.prefix(1)))
                .font(Theme.wordmark(120))
                .minimumScaleFactor(0.2)
                .lineLimit(1)
                .padding(12)
                .foregroundStyle(Theme.bone.opacity(0.9))
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }
}

#Preview {
    FeedView()
        .environment(WardrobeStore.sample())
}

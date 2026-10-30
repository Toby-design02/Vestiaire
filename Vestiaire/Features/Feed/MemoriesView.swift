import SwiftUI

/// Mes souvenirs, comme sur BeReal : tous mes OOTD rangés dans un calendrier.
struct MemoriesView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var opened: FeedPost?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var myPosts: [FeedPost] {
        store.feed.filter { $0.author.isMe }
    }

    /// Mon OOTD de chaque jour (le plus récent s'il y en a plusieurs).
    private var postsByDay: [Date: FeedPost] {
        var result: [Date: FeedPost] = [:]
        for post in myPosts {
            let day = calendar.startOfDay(for: post.date)
            if let existing = result[day], existing.date > post.date { continue }
            result[day] = post
        }
        return result
    }

    /// Nombre de jours d'affilée avec un OOTD, jusqu'à aujourd'hui.
    private var streak: Int {
        let days = postsByDay
        var count = 0
        var day = calendar.startOfDay(for: .now)
        while days[day] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private var months: [Date] {
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return (0..<3).compactMap { calendar.date(byAdding: .month, value: -$0, to: start) }
    }

    var body: some View {
        let days = postsByDay
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack(spacing: 28) {
                        figure("\(myPosts.count)", "OOTD postés")
                        figure("\(streak)", streak > 1 ? "jours d'affilée" : "jour d'affilée")
                        figure("\(myPosts.filter { $0.minutesLate == 0 }.count)", "à l'heure")
                    }
                    .padding(.horizontal, 16)

                    ForEach(months, id: \.self) { month in
                        monthGrid(month, days: days)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Theme.night)
            .navigationTitle("Mes souvenirs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .navigationDestination(item: $opened) { post in
                MemoryDetail(post: post)
            }
        }
        .tint(Theme.bone)
        .preferredColorScheme(.dark)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.display(40))
                .foregroundStyle(Theme.bone)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.nightMuted)
        }
    }

    private func monthGrid(_ month: Date, days: [Date: FeedPost]) -> some View {
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        // Semaine qui commence le lundi.
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday + 5) % 7
        let today = calendar.startOfDay(for: .now)

        return VStack(alignment: .leading, spacing: 12) {
            Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.bone)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { index in
                    Text(["L", "M", "M", "J", "V", "S", "D"][index])
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.nightMuted)
                }
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(range, id: \.self) { dayNumber in
                    let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: month) ?? month
                    dayCell(dayNumber, post: days[day], isFuture: day > today, isToday: day == today)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func dayCell(_ number: Int, post: FeedPost?, isFuture: Bool, isToday: Bool) -> some View {
        if let post {
            Button {
                opened = post
            } label: {
                PostImage(post: post)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .bottomLeading) {
                        Text("\(number)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .padding(4)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isToday ? Theme.bone : .clear, lineWidth: 2))
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.nightRaised.opacity(isFuture ? 0.35 : 1))
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isFuture ? Theme.nightMuted.opacity(0.4) : Theme.nightMuted)
                }
        }
    }
}

/// Un souvenir en grand.
private struct MemoryDetail: View {
    let post: FeedPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PostImage(post: post)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Theme.bone)
                    Text([post.place, post.date.timeFR, post.minutesLate > 0 ? "\(post.minutesLate) min de retard" : "à l'heure"].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.nightMuted)
                    if let caption = post.caption {
                        Text(caption)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.bone)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ce jour-là")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.nightMuted)
                    ForEach(post.pieces) { piece in
                        HStack(spacing: 12) {
                            ProductImage(item: piece, showsBackground: false)
                                .frame(width: 40, height: 40)
                                .padding(6)
                                .background(Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(piece.brand?.name ?? "Sans marque")
                                    .font(.system(size: 14, weight: .bold))
                                Text(piece.type)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.nightMuted)
                            }
                            .foregroundStyle(Theme.bone)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
        .background(Theme.night)
        .navigationBarTitleDisplayMode(.inline)
    }
}

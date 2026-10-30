import Foundation

/// Données d'exemple, en attendant le branchement sur le pipeline IA.
/// Toujours les mêmes à chaque lancement (générateur aléatoire à graine fixe).
extension WardrobeStore {
    static func sample(now: Date = .now) -> WardrobeStore {
        var rng = SeededGenerator(seed: 2026)
        let calendar = Calendar.current

        // (pièce, fréquence de port relative ; 0 = jamais portée, donc dormante)
        // Le dressing complet de Thibaut, à partir de ses photos produit.
        let catalog: [(Item, Double)] = [
            (piece(.knitwear, "Pull col rond", "Vert sapin", "2F4A3A", brand: "Jacquemus", paid: 290, retail: 320, resale: 170, material: "Laine", fit: "Droite", collar: "Col rond", front: "Bords côtelés", texts: ["JACQUEMUS"], image: "pull-vert-sapin"), 6),
            (piece(.bottoms, "Jean brut", "Indigo", "2B3A55", paid: 120, resale: 55, material: "Denim brut", fit: "Large", front: "Cinq poches, rivets cuivre", image: "jean-brut"), 6),
            (piece(.shoes, "Derbies Tabi", "Noir", "1C1C1C", brand: "Maison Margiela", brandModel: "Tabi", brandSource: .web, paid: 790, retail: 890, resale: 520, material: "Cuir lisse", front: "Bout fendu", image: "tabi-noires"), 4),
            (piece(.accessories, "Ceinture", "Noir", "1C1C1C", paid: 45, resale: 15, material: "Cuir", front: "Boucle ovale argent mat", image: "ceinture-noire"), 2),
        ]

        var items = catalog.map { $0.0 }
        for index in items.indices {
            items[index].sourcePhotos = [
                SourcePhoto(angle: .front, assetIdentifier: "exemple-\(index)-face"),
                SourcePhoto(angle: .back, assetIdentifier: "exemple-\(index)-dos"),
            ]
        }
        let weights = Dictionary(uniqueKeysWithValues: zip(items.map(\.id), catalog.map { $0.1 }))

        func roll() -> Double {
            Double.random(in: 0..<1, using: &rng)
        }

        func pick(_ category: ClothingCategory) -> Item? {
            let pool = items.filter { $0.category == category && (weights[$0.id] ?? 0) > 0 }
            let total = pool.reduce(0) { $0 + (weights[$1.id] ?? 0) }
            guard total > 0 else { return nil }
            var remaining = Double.random(in: 0..<total, using: &rng)
            for item in pool {
                remaining -= weights[item.id] ?? 0
                if remaining < 0 { return item }
            }
            return pool.last
        }

        // Une séance photo tous les 2 à 6 jours depuis ~20 mois.
        let places = ["Paris", "New Haven", "New York", "Biarritz"]
        var sessions: [Session] = []
        var wearEvents: [WearEvent] = []
        var outfits: [Outfit] = []
        var dayOffset = -600
        while dayOffset <= 0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { break }
            let month = calendar.component(.month, from: date)
            let winter = [11, 12, 1, 2, 3].contains(month)

            let session = Session(
                date: date,
                place: places.randomElement(using: &rng),
                context: SessionContext.allCases.randomElement(using: &rng) ?? .everyday,
                photoCount: Int.random(in: 1...14, using: &rng)
            )

            // Les selfies montrent surtout le haut : bas et chaussures apparaissent moins souvent.
            var worn: [Item] = []
            if roll() < 0.9, let item = pick(.baseLayer) { worn.append(item) }
            if roll() < (winter ? 0.7 : 0.25), let item = pick(.knitwear) { worn.append(item) }
            if roll() < (winter ? 0.75 : 0.1), let item = pick(.outerwear) { worn.append(item) }
            if roll() < 0.55, let item = pick(.bottoms) { worn.append(item) }
            if roll() < 0.3, let item = pick(.shoes) { worn.append(item) }
            if roll() < 0.2, let item = pick(.accessories) { worn.append(item) }

            sessions.append(session)
            wearEvents += worn.map { WearEvent(itemID: $0.id, sessionID: session.id, date: date) }
            outfits.append(Outfit(itemIDs: worn.map(\.id), date: date, source: .photo))
            dayOffset += Int.random(in: 2...6, using: &rng)
        }

        let friends = [
            User(displayName: "Léa"),
            User(displayName: "Hugo"),
            User(displayName: "Inès"),
        ]
        let user = User(displayName: "Thibaut", friendIDs: friends.map(\.id))

        func photo(_ name: String) -> Item? {
            items.first { $0.productImageName == name }
        }
        let byImage = ["pull-vert-sapin", "jean-brut", "tabi-noires", "ceinture-noire"].compactMap(photo)

        // OOTD d'aujourd'hui : la vraie photo, et les ports qui vont avec.
        let todaySession = Session(date: now.addingTimeInterval(-3 * 3600), place: "Paris", context: .everyday)
        let todayPieces = ["jean-brut", "ceinture-noire", "tabi-noires"].compactMap(photo)
        sessions.append(todaySession)
        wearEvents += todayPieces.map { WearEvent(itemID: $0.id, sessionID: todaySession.id, date: todaySession.date) }

        // Mes OOTD passés (souvenirs), à partir des tenues retrouvées dans la galerie.
        let me = FeedAuthor(id: user.id, name: user.displayName, handle: "@thibaut", hex: myColorHex, isMe: true)
        let backdrops = ["B99872", "CFCBC4", "E8E1D3", "DDE1E6", "C9D3C9"]
        let memoryStart = calendar.date(byAdding: .day, value: -80, to: now) ?? now
        var myPosts = outfits
            .filter { $0.itemIDs.count >= 2 && $0.date > memoryStart && !calendar.isDateInToday($0.date) }
            .enumerated()
            .map { index, outfit in
                FeedPost(
                    author: me,
                    circle: .friends,
                    date: outfit.date,
                    minutesLate: index % 4 == 0 ? 12 : 0,
                    place: "Paris",
                    pieces: outfit.itemIDs.compactMap { id in items.first { $0.id == id } },
                    backdropHex: backdrops[index % backdrops.count]
                )
            }
        myPosts.append(FeedPost(
            author: me,
            circle: .friends,
            date: todaySession.date,
            place: "Paris 3e",
            caption: "Jean large, Tabi, rien d'autre",
            pieces: todayPieces,
            photoName: "ootd-aujourdhui",
            backdropHex: "1C1C1C",
            reactions: [
                Reaction(authorName: "Léa", hex: "F5A8C6", emoji: "🔥"),
                Reaction(authorName: "Inès", hex: "D8F04A", emoji: "😍"),
            ],
            commentCount: 3
        ))

        // Tenues déjà proposées par l'agent.
        let generated = [
            GeneratedOutfit(
                date: now.addingTimeInterval(-26 * 3600),
                itemIDs: byImage.map(\.id),
                occasion: .everyday,
                style: .minimal,
                weather: "Paris · 12 °C, éclaircies",
                renderName: "outfit-chaise",
                reasons: [
                    "12 °C : on garde de la laine.",
                    "Le vert sapin est la seule couleur, le reste en noir et indigo.",
                    "La ceinture à boucle ovale marque la taille du jean large.",
                ]
            ),
            GeneratedOutfit(
                date: now.addingTimeInterval(-4 * 86_400),
                itemIDs: ["pull-vert-sapin", "jean-brut", "tabi-noires"].compactMap(photo).map(\.id),
                tryOn: TryOnPiece(description: "casquette Jacquemus beige"),
                occasion: .weekend,
                style: .relaxed,
                reasons: [
                    "Construite autour de la pièce que tu hésites à acheter : casquette Jacquemus beige.",
                    "Le beige adoucit le vert sapin.",
                ]
            ),
            GeneratedOutfit(
                date: now.addingTimeInterval(-9 * 86_400),
                itemIDs: ["pull-vert-sapin", "jean-brut", "tabi-noires", "ceinture-noire"].compactMap(photo).map(\.id),
                occasion: .work,
                style: .chic,
                weather: "Paris · 9 °C, pluie",
                reasons: ["Pour le travail : une seule couleur forte, le reste en noir et indigo."]
            ),
        ]

        let feed = sampleFeed(now: now) + myPosts
        let discover = sampleDiscover(feed: feed)

        return WardrobeStore(
            user: user,
            friends: friends,
            items: items,
            sessions: sessions,
            wearEvents: wearEvents,
            outfits: outfits,
            feed: feed,
            ootdMoment: now.addingTimeInterval(-25),
            generatedOutfits: generated,
            profiles: discover.profiles,
            trending: discover.trending,
            listings: discover.listings,
            recommendations: discover.recommendations
        )
    }

    /// Découvrir : profils publics et privés, tenues tendance, seconde main, recommandations.
    private static func sampleDiscover(feed: [FeedPost]) -> (profiles: [DiscoverProfile], trending: [TrendingOutfit], listings: [Listing], recommendations: [Recommendation]) {
        func author(_ name: String) -> FeedAuthor? {
            feed.first { $0.author.name == name }?.author
        }
        func piecesOf(_ name: String) -> [Item] {
            feed.filter { $0.author.name == name }.flatMap(\.pieces)
        }
        func openTo(_ item: Item, offers: Bool = true, swap: Bool = false) -> Item {
            var copy = item
            copy.openToOffers = offers
            copy.openToSwap = swap
            return copy
        }

        let camille = author("Camille Morel") ?? FeedAuthor(name: "Camille Morel", handle: "@camillemorel", hex: "C9A27E")
        let yanis = author("Yanis B.") ?? FeedAuthor(name: "Yanis B.", handle: "@yanis.fits", hex: "1F2A44")
        let margaux = author("Margaux") ?? FeedAuthor(name: "Margaux", handle: "@margauxdresse", hex: "6B1E2A")
        let nour = FeedAuthor(name: "Nour", handle: "@nour.archive", hex: "2F4A3A", followers: 87_300)
        let jules = FeedAuthor(name: "Jules", handle: "@jules.p", hex: "8E8981", viaFriend: "Hugo")

        let camilleExtra = [
            openTo(piece(.outerwear, "Manteau long", "Camel", "B98A5A", brand: "Lemaire", paid: 890, material: "Laine"), swap: true),
            openTo(piece(.knitwear, "Pull col roulé", "Écru", "EDE4D3", brand: "COS", paid: 89, material: "Laine mérinos")),
        ]
        let nourPieces = [
            openTo(piece(.outerwear, "Veste de travail", "Noir", "1C1C1C", brand: "Carhartt WIP", paid: 199, material: "Toile de coton"), swap: true),
            piece(.baseLayer, "T-shirt épais", "Blanc", "F4F2EE", brand: "COS", paid: 35),
            openTo(piece(.bottoms, "Pantalon large", "Gris anthracite", "4D4D4D", brand: "Our Legacy", paid: 260)),
            piece(.shoes, "Derbies", "Marron", "5A3A28", brand: "Paraboot", paid: 360),
            openTo(piece(.accessories, "Casquette", "Beige", "C9B99A", brand: "Jacquemus", paid: 120), offers: false, swap: true),
        ]
        let julesPieces = [
            piece(.knitwear, "Cardigan", "Marine", "1F2A44", brand: "Ami", paid: 280),
            piece(.bottoms, "Jean droit", "Noir", "222222", brand: "A.P.C.", paid: 190),
        ]

        let profiles = [
            DiscoverProfile(author: nour, isPublic: true, style: "Archive, workwear", pieces: nourPieces),
            DiscoverProfile(author: camille, isPublic: true, style: "Parisien, intemporel", pieces: piecesOf("Camille Morel") + camilleExtra),
            DiscoverProfile(author: yanis, isPublic: true, style: "Été toute l'année", pieces: piecesOf("Yanis B.")),
            DiscoverProfile(author: margaux, isPublic: true, style: "100 % seconde main", pieces: piecesOf("Margaux").map { openTo($0, swap: true) }),
            DiscoverProfile(author: jules, isPublic: false, style: "Minimal", pieces: julesPieces),
        ]

        let trending = [
            TrendingOutfit(profileID: nour.id, title: "Workwear noir et blanc", pieces: Array(nourPieces.prefix(4)), likes: 2_418, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: camille.id, title: "Camel et indigo", pieces: [camilleExtra[0], camilleExtra[1]] + piecesOf("Camille Morel").filter { $0.category == .bottoms || $0.category == .shoes }, likes: 1_904, backdropHex: "ECE9E3"),
            TrendingOutfit(profileID: margaux.id, title: "Tout noir, tout Vinted", pieces: piecesOf("Margaux"), likes: 1_210, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: yanis.id, title: "Oxford et lin", pieces: piecesOf("Yanis B."), likes: 986, backdropHex: "ECE9E3"),
            TrendingOutfit(profileID: nour.id, title: "Gris et marron", pieces: [nourPieces[1], nourPieces[2], nourPieces[3]], likes: 744, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: camille.id, title: "La marinière", pieces: piecesOf("Camille Morel"), likes: 655, backdropHex: "ECE9E3"),
        ]

        let listings = profiles.filter(\.isPublic).flatMap { profile in
            profile.pieces
                .filter { $0.openToOffers || $0.openToSwap }
                .map { item in
                    Listing(
                        profileID: profile.id,
                        item: item,
                        price: ((item.pricePaid ?? 60) * 0.55).rounded(),
                        size: item.category == .shoes ? "42" : "M",
                        condition: item.pricePaid ?? 0 > 300 ? "Très bon état" : "Bon état"
                    )
                }
        }

        let recommendations = [
            Recommendation(
                item: piece(.accessories, "Casquette", "Beige", "C9B99A", brand: "Jacquemus", paid: 120),
                price: 120,
                shop: "Jacquemus",
                headline: "La casquette Jacquemus irait bien avec ton pull vert sapin et ton jean brut",
                reason: "Le beige adoucit le vert, et Jacquemus est déjà la marque de ta pièce n°1."
            ),
            Recommendation(
                item: piece(.outerwear, "Veste de travail", "Noir", "1C1C1C", brand: "Carhartt WIP", paid: 199),
                price: 199,
                shop: "Carhartt WIP",
                headline: "Ton rayon Vestes est vide",
                reason: "À 11 °C ton pull ne suffira bientôt plus. Le noir reprend tes Tabi et ta ceinture."
            ),
            Recommendation(
                item: piece(.baseLayer, "T-shirt épais", "Blanc", "F4F2EE", brand: "COS", paid: 35),
                price: 35,
                shop: "COS",
                headline: "Il te manque une première couche",
                reason: "Sous ton pull, ou seul avec ton jean large dès qu'il fait beau."
            ),
        ]

        return (profiles, trending, listings, recommendations)
    }

    /// OOTD des amis et des amis d'amis (créateurs au vestiaire public).
    private static func sampleFeed(now: Date) -> [FeedPost] {
        func ago(_ minutes: Int) -> Date {
            now.addingTimeInterval(TimeInterval(-minutes * 60))
        }
        func react(_ entries: [(String, String, String)]) -> [Reaction] {
            entries.map { Reaction(authorName: $0.0, hex: $0.1, emoji: $0.2) }
        }

        let lea = FeedAuthor(name: "Léa", handle: "@lea.mrt", hex: "F5A8C6")
        let hugo = FeedAuthor(name: "Hugo", handle: "@hugo_d", hex: "2341D8")
        let ines = FeedAuthor(name: "Inès", handle: "@ines.k", hex: "D8F04A")
        let sacha = FeedAuthor(name: "Sacha", handle: "@sachaaa", hex: "15382A")
        let camille = FeedAuthor(name: "Camille Morel", handle: "@camillemorel", hex: "C9A27E", followers: 48_200, viaFriend: "Léa")
        let yanis = FeedAuthor(name: "Yanis B.", handle: "@yanis.fits", hex: "1F2A44", followers: 12_900, viaFriend: "Hugo")
        let margaux = FeedAuthor(name: "Margaux", handle: "@margauxdresse", hex: "6B1E2A", followers: 3_400, viaFriend: "Inès")

        return [
            FeedPost(author: lea, circle: .friends, date: ago(4), place: "Paris 11e", caption: "Retour du trench, enfin",
                     pieces: [
                         piece(.outerwear, "Trench", "Beige", "C8B48F", brand: "Arket", paid: 189),
                         piece(.baseLayer, "T-shirt", "Blanc", "F4F2EE", brand: "COS", paid: 35),
                         piece(.bottoms, "Jean droit", "Bleu clair", "8FA8C4", brand: "Levi's", paid: 110),
                         piece(.shoes, "Mocassins", "Noir", "1C1C1C", brand: "G.H. Bass", paid: 160),
                     ],
                     backdropHex: "B99872",
                     reactions: react([("Hugo", "2341D8", "🔥"), ("Inès", "D8F04A", "😍")]), commentCount: 2),
            FeedPost(author: hugo, circle: .friends, date: ago(11), minutesLate: 9, place: "HEC, Jouy-en-Josas",
                     pieces: [
                         piece(.knitwear, "Sweat à capuche", "Gris", "A3A3A3", brand: "Carhartt WIP", paid: 99),
                         piece(.bottoms, "Pantalon cargo", "Kaki", "5E6044", brand: "Dickies", paid: 70),
                         piece(.shoes, "Baskets", "Blanc", "F1EFEA", brand: "Nike", paid: 110),
                         piece(.accessories, "Casquette", "Noir", "1E1E1E", brand: "New Era", paid: 30),
                     ],
                     backdropHex: "CFCBC4",
                     reactions: react([("Léa", "F5A8C6", "😂")]), commentCount: 1),
            FeedPost(author: ines, circle: .friends, date: ago(26), place: "Lyon", caption: "Cachemire + lin, le combo d'automne",
                     pieces: [
                         piece(.knitwear, "Pull en cachemire", "Bordeaux", "6B1E2A", brand: "Sézane", paid: 160),
                         piece(.bottoms, "Pantalon large", "Écru", "E9E1CF", brand: "Rouje", paid: 95),
                         piece(.shoes, "Bottines", "Marron", "5A3A28", brand: "Jonak", paid: 140),
                     ],
                     backdropHex: "E8E1D3",
                     reactions: react([("Léa", "F5A8C6", "😍"), ("Sacha", "15382A", "👏"), ("Hugo", "2341D8", "🔥")]), commentCount: 4),
            FeedPost(author: sacha, circle: .friends, date: ago(52), minutesLate: 38, place: "Bordeaux",
                     pieces: [
                         piece(.outerwear, "Veste en jean", "Indigo", "2B3A55", brand: "A.P.C.", paid: 230),
                         piece(.baseLayer, "T-shirt", "Noir", "1E1E1E", paid: 20),
                         piece(.bottoms, "Pantalon de costume", "Gris", "6E6E6E", brand: "Zara", paid: 50),
                         piece(.shoes, "Running", "Gris", "9A9A9A", brand: "New Balance", paid: 120),
                     ],
                     backdropHex: "DDE1E6"),
            FeedPost(author: camille, circle: .discovery, date: ago(18), place: "Paris 6e", caption: "Uniforme du mardi. Tout est en lien dans mon vestiaire.",
                     pieces: [
                         piece(.outerwear, "Caban en laine", "Marine", "1F2A44", brand: "Saint James", paid: 350),
                         piece(.knitwear, "Pull marin", "Blanc et marine", "E9ECF1", brand: "Armor-Lux", paid: 95, pattern: "Rayures"),
                         piece(.bottoms, "Jean brut", "Indigo", "2B3A55", brand: "A.P.C.", paid: 200),
                         piece(.shoes, "Mocassins", "Bordeaux", "4A1A22", brand: "J.M. Weston", paid: 690),
                         piece(.accessories, "Écharpe", "Camel", "B98A5A", brand: "Acne Studios", paid: 180),
                     ],
                     backdropHex: "B99872",
                     reactions: react([("Léa", "F5A8C6", "😍"), ("Margaux", "6B1E2A", "🔥")]), commentCount: 31, audience: .everyone),
            FeedPost(author: yanis, circle: .discovery, date: ago(44), place: "Marseille",
                     pieces: [
                         piece(.baseLayer, "Chemise oxford", "Bleu ciel", "A9C4E0", brand: "Ralph Lauren", paid: 139),
                         piece(.bottoms, "Short en lin", "Sable", "D8C8A8", brand: "Arket", paid: 59),
                         piece(.shoes, "Baskets", "Blanc", "F1EFEA", brand: "Veja", paid: 150),
                         piece(.accessories, "Lunettes de soleil", "Noir", "1C1C1C", brand: "Ray-Ban", paid: 160),
                     ],
                     backdropHex: "C9D3C9",
                     reactions: react([("Hugo", "2341D8", "👏")]), commentCount: 12, audience: .everyone),
            FeedPost(author: margaux, circle: .discovery, date: ago(95), minutesLate: 70, place: "Lille", caption: "Tout vient de Vinted, sauf les bottines",
                     pieces: [
                         piece(.outerwear, "Doudoune légère", "Noir", "1C1C1C", brand: "Uniqlo", paid: 35),
                         piece(.knitwear, "Cardigan", "Crème", "EDE4D3", paid: 18),
                         piece(.bottoms, "Jupe longue", "Noir", "222222", paid: 12),
                         piece(.shoes, "Bottines", "Noir", "1C1C1C", brand: "Dr. Martens", paid: 189),
                     ],
                     backdropHex: "E8E1D3", commentCount: 7, audience: .everyone),
        ]
    }

    private static func piece(
        _ category: ClothingCategory,
        _ type: String,
        _ color: String,
        _ hex: String,
        brand: String? = nil,
        brandModel: String? = nil,
        brandSource: BrandSource = .photo,
        paid: Double? = nil,
        retail: Double? = nil,
        resale: Double? = nil,
        material: String? = nil,
        fit: String? = nil,
        pattern: String? = nil,
        collar: String? = nil,
        front: String? = nil,
        back: String? = nil,
        texts: [String] = [],
        image: String? = nil
    ) -> Item {
        Item(
            category: category,
            type: type,
            colors: [color],
            colorHex: hex,
            pattern: pattern,
            material: material,
            fit: fit,
            collar: collar,
            frontDetails: front,
            backDetails: back,
            detectedTexts: texts,
            brand: brand.map { BrandInfo(name: $0, model: brandModel, confidence: brandSource == .photo ? 0.92 : 0.81, source: brandSource) },
            pricePaid: paid,
            priceNew: retail,
            resaleValue: resale,
            productImageName: image
        )
    }
}

/// Générateur pseudo-aléatoire reproductible (mêmes données à chaque lancement).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

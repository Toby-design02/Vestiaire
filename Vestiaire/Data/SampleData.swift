import Foundation

/// Données d'exemple, en attendant le branchement sur le pipeline IA.
/// Toujours les mêmes à chaque lancement (générateur aléatoire à graine fixe).
extension WardrobeStore {
    static func sample(now: Date = .now) -> WardrobeStore {
        var rng = SeededGenerator(seed: 2026)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        let uniform = ItemTag(name: "Uniforme")
        let statement = ItemTag(name: "Pièces fortes")
        let tailor = ItemTag(name: "À retoucher")

        // (pièce, fréquence de port relative ; 0 = jamais portée, donc dormante)
        // Le dressing complet de Thibaut, à partir de ses photos produit.
        var pull = piece(.knitwear, "Pull col rond", "Vert sapin", "2F4A3A", brand: "Jacquemus", paid: 290, retail: 320, resale: 170, material: "Laine", fit: "Droite", collar: "Col rond", front: "Bords côtelés", texts: ["JACQUEMUS"], image: "pull-vert-sapin")
        pull.isFavorite = true
        pull.seasons = [.autumn, .winter]
        pull.occasions = [.everyday, .work, .weekend]
        pull.tagIDs = [statement.id]
        var jean = piece(.bottoms, "Jean brut", "Indigo", "2B3A55", paid: 120, resale: 55, material: "Denim brut", fit: "Large", front: "Cinq poches, rivets cuivre", image: "jean-brut")
        jean.seasons = [.spring, .autumn, .winter]
        jean.occasions = [.everyday, .weekend]
        jean.tagIDs = [uniform.id, tailor.id]
        var tabi = piece(.shoes, "Derbies Tabi", "Noir", "1C1C1C", brand: "Maison Margiela", brandModel: "Tabi", brandSource: .web, paid: 790, retail: 890, resale: 520, material: "Cuir lisse", front: "Bout fendu", image: "tabi-noires")
        tabi.isFavorite = true
        tabi.seasons = [.spring, .autumn, .winter]
        tabi.occasions = [.work, .evening]
        tabi.tagIDs = [uniform.id, statement.id]
        var belt = piece(.accessories, "Ceinture", "Noir", "1C1C1C", paid: 45, resale: 15, material: "Cuir", front: "Boucle ovale argent mat", image: "ceinture-noire")
        belt.seasons = Set(Season.allCases)
        belt.occasions = [.work, .evening]
        belt.tagIDs = [uniform.id]
        // Rangée dans les archives pour l'hiver : son historique de port reste dans le journal.
        var shirt = piece(.baseLayer, "Chemise oxford", "Bleu ciel", "A9C4E0", brand: "Ralph Lauren", paid: 139, resale: 40, material: "Coton oxford", collar: "Col boutonné")
        shirt.seasons = [.spring, .summer]
        shirt.occasions = [.work, .everyday]

        let catalog: [(Item, Double)] = [(pull, 6), (jean, 6), (tabi, 4), (belt, 2), (shirt, 3)]

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

        // Tenues retrouvées dans la galerie : une séance photo tous les 2 à 6 jours depuis ~20 mois.
        // Ce sont des données d'exemple, marquées comme telles dans le journal et les statistiques.
        let places = ["Paris", "New Haven", "New York", "Biarritz"]
        var sessions: [Session] = []
        var wearEvents: [WearEvent] = []
        var dayOffset = -600
        while dayOffset < 0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { break }
            let month = calendar.component(.month, from: date)
            let winter = [11, 12, 1, 2, 3].contains(month)

            let session = Session(
                date: date,
                place: places.randomElement(using: &rng),
                context: SessionContext.allCases.randomElement(using: &rng) ?? .everyday,
                photoCount: Int.random(in: 1...14, using: &rng),
                isSample: true
            )

            // Les selfies montrent surtout le haut : bas et chaussures apparaissent moins souvent.
            // La chemise oxford n'est plus portée depuis qu'elle est rangée (4 derniers mois).
            var worn: [Item] = []
            if dayOffset < -120, roll() < 0.6, let item = pick(.baseLayer) { worn.append(item) }
            if roll() < (winter ? 0.7 : 0.25), let item = pick(.knitwear) { worn.append(item) }
            if roll() < (winter ? 0.75 : 0.1), let item = pick(.outerwear) { worn.append(item) }
            if roll() < 0.55, let item = pick(.bottoms) { worn.append(item) }
            if roll() < 0.3, let item = pick(.shoes) { worn.append(item) }
            if roll() < 0.2, let item = pick(.accessories) { worn.append(item) }

            if !worn.isEmpty {
                sessions.append(session)
                wearEvents += worn.map { WearEvent(itemID: $0.id, sessionID: session.id, date: date) }
            }
            dayOffset += Int.random(in: 2...6, using: &rng)
        }

        if let index = items.firstIndex(where: { $0.id == shirt.id }) {
            items[index].status = .archived
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
            GeneratedOutfit(
                date: now.addingTimeInterval(-30 * 86_400),
                itemIDs: [shirt.id, jean.id, belt.id],
                occasion: .work,
                style: .minimal,
                weather: "Paris · 19 °C, soleil",
                reasons: ["19 °C : la chemise suffit."],
                isArchived: true
            ),
        ]

        // Journal : la tenue d'hier, marquée comme portée depuis l'agent, et celle d'aujourd'hui avec sa photo.
        let yesterday = Session(date: now.addingTimeInterval(-24 * 3600), place: "Paris", context: .work, origin: .journal, outfitID: generated[0].id, isSample: true)
        sessions.append(yesterday)
        wearEvents += generated[0].itemIDs.map { WearEvent(itemID: $0, sessionID: yesterday.id, date: yesterday.date) }

        let todaySession = Session(date: now.addingTimeInterval(-3 * 3600), place: "Paris", context: .everyday, origin: .journal, samplePhotoName: "ootd-aujourdhui", isSample: true)
        let todayPieces = ["jean-brut", "ceinture-noire", "tabi-noires"].compactMap(photo)
        sessions.append(todaySession)
        wearEvents += todayPieces.map { WearEvent(itemID: $0.id, sessionID: todaySession.id, date: todaySession.date) }

        // Agenda : un dîner, un week-end à venir, et un voyage passé avec sa valise.
        let dinner = WardrobeEvent(name: "Dîner d'anniversaire", start: day(4), end: day(4), place: "Paris 11e", isSample: true)
        let biarritz = WardrobeEvent(name: "Week-end à Biarritz", kind: .travel, start: day(10), end: day(12), place: "Biarritz", isSample: true)
        let newYork = WardrobeEvent(name: "New York", kind: .travel, start: day(-40), end: day(-37), place: "New York", isSample: true)

        let plans = [
            PlannedOutfit(date: day(4), itemIDs: generated[2].itemIDs, outfitID: generated[2].id, eventID: dinner.id, isSample: true),
            PlannedOutfit(date: day(10), itemIDs: generated[0].itemIDs, outfitID: generated[0].id, eventID: biarritz.id, isSample: true),
            PlannedOutfit(date: day(11), itemIDs: generated[1].itemIDs, outfitID: generated[1].id, eventID: biarritz.id, isSample: true),
            PlannedOutfit(date: day(-40), itemIDs: [jean.id, pull.id, tabi.id], eventID: newYork.id, isSample: true),
            PlannedOutfit(date: day(-39), itemIDs: [shirt.id, jean.id, belt.id], eventID: newYork.id, isSample: true),
            PlannedOutfit(date: day(-38), itemIDs: [pull.id, jean.id, tabi.id, belt.id], eventID: newYork.id, isSample: true),
        ]

        let packingLists = [
            PackingList(eventID: biarritz.id, packedItemIDs: [jean.id], extras: [
                PackingExtra(name: "Trousse de toilette"),
                PackingExtra(name: "Chargeur", isPacked: true),
            ]),
            PackingList(eventID: newYork.id, packedItemIDs: [jean.id, pull.id, tabi.id, shirt.id, belt.id], extras: [
                PackingExtra(name: "Passeport", isPacked: true),
                PackingExtra(name: "Adaptateur US", isPacked: true),
            ]),
        ]

        let discover = sampleDiscover()

        let store = WardrobeStore(
            user: user,
            friends: friends,
            items: items,
            sessions: sessions,
            wearEvents: wearEvents,
            generatedOutfits: generated,
            tags: [uniform, statement, tailor],
            events: [dinner, biarritz, newYork],
            plans: plans,
            packingLists: packingLists,
            profiles: discover.profiles,
            trending: discover.trending,
            listings: discover.listings,
            recommendations: discover.recommendations
        )

        // Liste d'envies : ajoutée après coup pour relier chaque article aux pièces semblables du dressing.
        let wishes = [
            Wish(description: "Casquette Jacquemus beige", estimatedPrice: 120, url: "https://www.jacquemus.com", addedAt: now.addingTimeInterval(-5 * 86_400), source: .discover),
            Wish(description: "Pantalon bleu", estimatedPrice: 95, addedAt: now.addingTimeInterval(-2 * 86_400), source: .fittingRoom),
            Wish(description: "Veste de travail Carhartt noire", estimatedPrice: 199, addedAt: now.addingTimeInterval(-12 * 86_400)),
        ]
        for wish in wishes {
            var sample = wish
            sample.isSample = true
            store.addWish(sample)
        }

        return store
    }

    /// Découvrir : profils publics et privés, tenues tendance, seconde main, recommandations.
    private static func sampleDiscover() -> (profiles: [DiscoverProfile], trending: [TrendingOutfit], listings: [Listing], recommendations: [Recommendation]) {
        func openTo(_ item: Item, offers: Bool = true, swap: Bool = false) -> Item {
            var copy = item
            copy.openToOffers = offers
            copy.openToSwap = swap
            return copy
        }

        let camille = ProfileAuthor(name: "Camille Morel", handle: "@camillemorel", hex: "C9A27E", followers: 48_200, viaFriend: "Léa")
        let yanis = ProfileAuthor(name: "Yanis B.", handle: "@yanis.fits", hex: "1F2A44", followers: 12_900, viaFriend: "Hugo")
        let margaux = ProfileAuthor(name: "Margaux", handle: "@margauxdresse", hex: "6B1E2A", followers: 3_400, viaFriend: "Inès")
        let nour = ProfileAuthor(name: "Nour", handle: "@nour.archive", hex: "2F4A3A", followers: 87_300)
        let jules = ProfileAuthor(name: "Jules", handle: "@jules.p", hex: "8E8981", viaFriend: "Hugo")

        let camillePieces = [
            piece(.outerwear, "Caban en laine", "Marine", "1F2A44", brand: "Saint James", paid: 350),
            piece(.knitwear, "Pull marin", "Blanc et marine", "E9ECF1", brand: "Armor-Lux", paid: 95, pattern: "Rayures"),
            piece(.bottoms, "Jean brut", "Indigo", "2B3A55", brand: "A.P.C.", paid: 200),
            piece(.shoes, "Mocassins", "Bordeaux", "4A1A22", brand: "J.M. Weston", paid: 690),
            piece(.accessories, "Écharpe", "Camel", "B98A5A", brand: "Acne Studios", paid: 180),
        ]
        let yanisPieces = [
            piece(.baseLayer, "Chemise oxford", "Bleu ciel", "A9C4E0", brand: "Ralph Lauren", paid: 139),
            piece(.bottoms, "Short en lin", "Sable", "D8C8A8", brand: "Arket", paid: 59),
            piece(.shoes, "Baskets", "Blanc", "F1EFEA", brand: "Veja", paid: 150),
            piece(.accessories, "Lunettes de soleil", "Noir", "1C1C1C", brand: "Ray-Ban", paid: 160),
        ]
        let margauxPieces = [
            piece(.outerwear, "Doudoune légère", "Noir", "1C1C1C", brand: "Uniqlo", paid: 35),
            piece(.knitwear, "Cardigan", "Crème", "EDE4D3", paid: 18),
            piece(.bottoms, "Jupe longue", "Noir", "222222", paid: 12),
            piece(.shoes, "Bottines", "Noir", "1C1C1C", brand: "Dr. Martens", paid: 189),
        ]
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
            DiscoverProfile(author: camille, isPublic: true, style: "Parisien, intemporel", pieces: camillePieces + camilleExtra),
            DiscoverProfile(author: yanis, isPublic: true, style: "Été toute l'année", pieces: yanisPieces),
            DiscoverProfile(author: margaux, isPublic: true, style: "100 % seconde main", pieces: margauxPieces.map { openTo($0, swap: true) }),
            DiscoverProfile(author: jules, isPublic: false, style: "Minimal", pieces: julesPieces),
        ]

        let trending = [
            TrendingOutfit(profileID: nour.id, title: "Workwear noir et blanc", pieces: Array(nourPieces.prefix(4)), likes: 2_418, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: camille.id, title: "Camel et indigo", pieces: [camilleExtra[0], camilleExtra[1]] + camillePieces.filter { $0.category == .bottoms || $0.category == .shoes }, likes: 1_904, backdropHex: "ECE9E3"),
            TrendingOutfit(profileID: margaux.id, title: "Tout noir, tout Vinted", pieces: margauxPieces, likes: 1_210, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: yanis.id, title: "Oxford et lin", pieces: yanisPieces, likes: 986, backdropHex: "ECE9E3"),
            TrendingOutfit(profileID: nour.id, title: "Gris et marron", pieces: [nourPieces[1], nourPieces[2], nourPieces[3]], likes: 744, backdropHex: "F3F2EF"),
            TrendingOutfit(profileID: camille.id, title: "La marinière", pieces: camillePieces, likes: 655, backdropHex: "ECE9E3"),
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

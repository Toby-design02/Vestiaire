import SwiftUI

/// Dessin à plat d'un vêtement (« flat » de styliste), utilisé tant que le pipeline IA
/// n'a pas généré la photo produit. Les tracés sont dessinés dans un carré de 100 × 100.
enum GarmentKind {
    case tee, knit, shirt, coat, puffer, jacket, pants, shorts, sneaker, boot, loafer, cap, scarf, glasses, belt

    init(item: Item) {
        let type = item.type.lowercased()
        switch item.category {
        case .outerwear:
            if type.contains("doudoune") { self = .puffer }
            else if type.contains("jean") { self = .jacket }
            else { self = .coat }
        case .knitwear:
            self = .knit
        case .baseLayer:
            self = type.contains("chemise") ? .shirt : .tee
        case .bottoms:
            self = type.contains("short") ? .shorts : .pants
        case .shoes:
            if type.contains("bottine") { self = .boot }
            else if type.contains("mocassin") { self = .loafer }
            else { self = .sneaker }
        case .accessories:
            if type.contains("casquette") { self = .cap }
            else if type.contains("écharpe") { self = .scarf }
            else if type.contains("ceinture") { self = .belt }
            else { self = .glasses }
        }
    }
}

struct GarmentDrawing: View {
    let item: Item

    var body: some View {
        let kind = GarmentKind(item: item)
        let fill = Color(hex: item.colorHex)
        let isLight = Theme.isLight(hex: item.colorHex, threshold: 0.75)
        let seam = Color.black.opacity(isLight ? 0.28 : 0.35)
        let outline = GarmentOutline(kind: kind)

        ZStack {
            outline.fill(fill)
            if let stripes = stripeColor {
                Stripes(vertical: kind == .shirt)
                    .stroke(stripes, lineWidth: kind == .shirt ? 1.2 : 2.6)
                    .clipShape(outline)
            }
            // Léger modelé, pour éviter l'effet aplat de vecteur.
            outline.fill(
                LinearGradient(colors: [.white.opacity(0.10), .black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            GarmentDetails(kind: kind)
                .stroke(seam, style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
            outline
                .stroke(Color.black.opacity(isLight ? 0.35 : 0.2), lineWidth: 0.8)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var stripeColor: Color? {
        guard item.pattern?.lowercased().contains("rayure") == true else { return nil }
        return Color(hex: "22304D").opacity(0.85)
    }
}

/// Raccourci : un point exprimé dans le carré 100 × 100, ramené au cadre réel.
private struct Grid100 {
    let rect: CGRect
    func callAsFunction(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x / 100, y: rect.minY + rect.height * y / 100)
    }
}

private struct GarmentOutline: Shape {
    let kind: GarmentKind

    func path(in rect: CGRect) -> Path {
        let p = Grid100(rect: rect)
        var path = Path()

        func polygon(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: p(first.0, first.1))
            for point in points.dropFirst() {
                path.addLine(to: p(point.0, point.1))
            }
            path.closeSubpath()
        }

        func top(neck: CGFloat, hem: CGFloat, width: CGFloat, longSleeve: Bool) {
            let left = 50 - width / 2
            let right = 50 + width / 2
            path.move(to: p(39, neck))
            path.addQuadCurve(to: p(61, neck), control: p(50, neck + 9))
            path.addLine(to: p(right + 4, neck + 4))
            if longSleeve {
                path.addLine(to: p(right + 21, hem - 8))
                path.addLine(to: p(right + 11, hem - 4))
                path.addLine(to: p(right, neck + 24))
            } else {
                path.addLine(to: p(right + 21, neck + 24))
                path.addLine(to: p(right + 12, neck + 32))
                path.addLine(to: p(right, neck + 24))
            }
            path.addLine(to: p(right, hem))
            path.addQuadCurve(to: p(left, hem), control: p(50, hem + 1.5))
            path.addLine(to: p(left, neck + 24))
            if longSleeve {
                path.addLine(to: p(left - 11, hem - 4))
                path.addLine(to: p(left - 21, hem - 8))
            } else {
                path.addLine(to: p(left - 12, neck + 32))
                path.addLine(to: p(left - 21, neck + 24))
            }
            path.addLine(to: p(left - 4, neck + 4))
            path.closeSubpath()
        }

        switch kind {
        case .tee:
            top(neck: 14, hem: 88, width: 50, longSleeve: false)
        case .knit:
            top(neck: 10, hem: 88, width: 52, longSleeve: true)
        case .shirt:
            top(neck: 10, hem: 90, width: 50, longSleeve: true)
        case .coat:
            top(neck: 4, hem: 98, width: 54, longSleeve: true)
        case .puffer:
            top(neck: 8, hem: 86, width: 58, longSleeve: true)
        case .jacket:
            top(neck: 12, hem: 78, width: 54, longSleeve: true)
        case .pants:
            polygon([(30, 4), (70, 4), (76, 97), (56, 97), (50, 34), (44, 97), (24, 97)])
        case .shorts:
            polygon([(26, 22), (74, 22), (80, 72), (55, 74), (50, 48), (45, 74), (20, 72)])
        case .sneaker:
            path.move(to: p(6, 74))
            path.addLine(to: p(7, 56))
            path.addQuadCurve(to: p(16, 44), control: p(8, 46))
            path.addLine(to: p(34, 44))
            path.addLine(to: p(50, 38))
            path.addQuadCurve(to: p(90, 60), control: p(78, 44))
            path.addQuadCurve(to: p(95, 74), control: p(97, 64))
            path.closeSubpath()
        case .loafer:
            path.move(to: p(6, 72))
            path.addLine(to: p(8, 56))
            path.addQuadCurve(to: p(28, 52), control: p(14, 50))
            path.addQuadCurve(to: p(92, 62), control: p(70, 48))
            path.addQuadCurve(to: p(94, 72), control: p(97, 67))
            path.closeSubpath()
        case .boot:
            path.move(to: p(14, 78))
            path.addLine(to: p(16, 22))
            path.addLine(to: p(44, 22))
            path.addLine(to: p(46, 50))
            path.addQuadCurve(to: p(90, 66), control: p(80, 52))
            path.addQuadCurve(to: p(92, 78), control: p(96, 72))
            path.closeSubpath()
        case .cap:
            path.move(to: p(18, 60))
            path.addQuadCurve(to: p(74, 60), control: p(44, 6))
            path.addQuadCurve(to: p(94, 70), control: p(92, 60))
            path.addQuadCurve(to: p(18, 64), control: p(60, 70))
            path.closeSubpath()
        case .scarf:
            path.addRoundedRect(in: CGRect(origin: p(36, 6), size: CGSize(width: rect.width * 0.16, height: rect.height * 0.86)), cornerSize: CGSize(width: 2, height: 2))
            path.addRoundedRect(in: CGRect(origin: p(50, 10), size: CGSize(width: rect.width * 0.16, height: rect.height * 0.7)), cornerSize: CGSize(width: 2, height: 2))
        case .glasses:
            path.addEllipse(in: CGRect(origin: p(10, 36), size: CGSize(width: rect.width * 0.34, height: rect.height * 0.26)))
            path.addEllipse(in: CGRect(origin: p(56, 36), size: CGSize(width: rect.width * 0.34, height: rect.height * 0.26)))
            path.addRect(CGRect(origin: p(43, 40), size: CGSize(width: rect.width * 0.14, height: rect.height * 0.03)))
        case .belt:
            path.addRoundedRect(in: CGRect(origin: p(4, 45), size: CGSize(width: rect.width * 0.92, height: rect.height * 0.1)), cornerSize: CGSize(width: 2, height: 2))
        }
        return path
    }
}

/// Coutures et détails dessinés par-dessus la forme.
private struct GarmentDetails: Shape {
    let kind: GarmentKind

    func path(in rect: CGRect) -> Path {
        let p = Grid100(rect: rect)
        var path = Path()

        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: p(a.0, a.1))
            path.addLine(to: p(b.0, b.1))
        }

        switch kind {
        case .tee:
            path.move(to: p(41, 15))
            path.addQuadCurve(to: p(59, 15), control: p(50, 22))
        case .knit:
            path.move(to: p(41, 11))
            path.addQuadCurve(to: p(59, 11), control: p(50, 18))
            line((24, 82), (76, 82))
            line((83, 76), (93, 79))
            line((17, 76), (7, 79))
        case .shirt:
            line((39, 10), (45, 22))
            line((61, 10), (55, 22))
            line((45, 22), (50, 17))
            line((55, 22), (50, 17))
            line((50, 18), (50, 90))
        case .coat:
            line((39, 4), (50, 40))
            line((61, 4), (50, 40))
            line((50, 40), (50, 98))
            line((30, 64), (40, 64))
            line((60, 64), (70, 64))
        case .puffer:
            for y in stride(from: 24, through: 80, by: 11) {
                line((21, CGFloat(y)), (79, CGFloat(y)))
            }
            line((50, 8), (50, 86))
        case .jacket:
            line((50, 14), (50, 78))
            line((29, 36), (44, 36))
            line((56, 36), (71, 36))
            line((23, 70), (77, 70))
        case .pants:
            line((30, 10), (70, 10))
            line((50, 10), (50, 26))
            line((36, 10), (34, 20))
            line((64, 10), (66, 20))
        case .shorts:
            line((26, 28), (74, 28))
            line((50, 28), (50, 40))
        case .sneaker:
            line((7, 66), (94, 66))
            line((40, 46), (52, 52))
            line((44, 43), (56, 49))
            line((48, 40), (60, 46))
        case .loafer:
            line((8, 66), (93, 66))
            path.move(to: p(46, 54))
            path.addQuadCurve(to: p(70, 54), control: p(58, 60))
        case .boot:
            line((15, 70), (92, 70))
            line((44, 24), (44, 50))
        case .cap:
            line((46, 22), (46, 58))
        case .scarf:
            for x in stride(from: 37, through: 51, by: 3) {
                line((CGFloat(x), 92), (CGFloat(x), 97))
            }
        case .glasses:
            line((10, 42), (3, 38))
            line((90, 42), (97, 38))
        case .belt:
            path.addRect(CGRect(origin: p(10, 43), size: CGSize(width: rect.width * 0.1, height: rect.height * 0.14)))
        }
        return path
    }
}

private struct Stripes: Shape {
    let vertical: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width * (vertical ? 0.035 : 0.07)
        var offset: CGFloat = 0
        while offset < (vertical ? rect.width : rect.height) {
            if vertical {
                path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + offset))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + offset))
            }
            offset += step
        }
        return path
    }
}

#Preview {
    let store = WardrobeStore.sample()
    return ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
            ForEach(store.items) { item in
                GarmentDrawing(item: item).padding(8).background(Theme.card)
            }
        }
    }
}

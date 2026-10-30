import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rend transparent le fond blanc d'une photo produit (seuil doux), puis recadre.
// Usage : swift tools/detourer.swift photo.jpg sortie.png
let input = CommandLine.arguments[1], output = CommandLine.arguments[2]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = image.width, h = image.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
for i in stride(from: 0, to: pixels.count, by: 4) {
    let m = min(pixels[i], pixels[i + 1], pixels[i + 2])
    // 225+ = fond ; 185-225 = bord adouci (enlève aussi l'ombre portée grise)
    let alpha: Double = m >= 225 ? 0 : (m <= 185 ? 1 : pow(Double(225 - Int(m)) / 40, 2))
    for c in 0..<4 { pixels[i + c] = UInt8(Double(pixels[i + c]) * alpha) }
}
// Recadre au plus près du vêtement (avec une petite marge), pour que toutes les pièces aient la même échelle.
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 25 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
let margin = max(maxX - minX, maxY - minY) / 40
let crop = CGRect(x: max(0, minX - margin), y: max(0, minY - margin),
                  width: min(w, maxX + margin) - max(0, minX - margin),
                  height: min(h, maxY + margin) - max(0, minY - margin))
let out = ctx.makeImage()!.cropping(to: crop)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out, nil)
CGImageDestinationFinalize(dest)

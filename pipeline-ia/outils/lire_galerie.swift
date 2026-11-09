// Étape 0 (sur le Mac, gratuite) : lit la photothèque comme le fera l'app sur l'iPhone.
// Même API (PhotoKit), même demande d'accès aux photos, mêmes identifiants de photos.
// Photos uniquement : vidéos et captures d'écran ignorées, photos prises avant date_min ignorées.
// Écrit une copie de travail de chaque photo (1280 px, JPEG) dans data/galerie/ et l'index
// data/galerie.jsonl (fichier, identifiant de la photo, date). Rien ne quitte le Mac.
// On peut couper et relancer : les photos déjà copiées sont sautées.
//
// Usage, depuis le dossier pipeline-ia :
//   swiftc -O outils/lire_galerie.swift -o outils/lire_galerie && ./outils/lire_galerie
import Foundation
import Photos
import ImageIO
import UniformTypeIdentifiers

let racine = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let config = try! JSONSerialization.jsonObject(with: Data(contentsOf: racine.appendingPathComponent("config.json"))) as! [String: Any]
let dateMin = ISO8601DateFormatter().date(from: (config["date_min"] as! String) + "T00:00:00Z")!
let dossier = racine.appendingPathComponent("data/galerie")
try! FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

// 1. Accès aux photos (le Mac affiche la même demande que l'iPhone)
let sem = DispatchSemaphore(value: 0)
var statut = PHAuthorizationStatus.notDetermined
PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in statut = s; sem.signal() }
sem.wait()
guard statut == .authorized || statut == .limited else {
    print("Accès aux photos refusé. Réglages Système > Confidentialité et sécurité > Photos : autorise le Terminal, puis relance.")
    exit(1)
}

// 2. Liste des photos (pas de vidéos, pas de captures d'écran)
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "creationDate >= %@", dateMin as NSDate)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
var photos: [PHAsset] = []
PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { a, _, _ in
    if !a.mediaSubtypes.contains(.photoScreenshot) { photos.append(a) }
}

let fmt = DateFormatter()
fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
fmt.locale = Locale(identifier: "en_US_POSIX")
func nomFichier(_ a: PHAsset) -> String {
    a.localIdentifier.replacingOccurrences(of: "/", with: "_") + ".jpg"
}

// 3. Index (fichier, identifiant, date), réécrit à chaque lancement
var index = ""
for a in photos {
    let ligne: [String: Any] = ["f": nomFichier(a), "id": a.localIdentifier, "dt": fmt.string(from: a.creationDate ?? Date()),
                                "fav": a.isFavorite]
    index += String(data: try! JSONSerialization.data(withJSONObject: ligne), encoding: .utf8)! + "\n"
}
try! index.write(to: racine.appendingPathComponent("data/galerie.jsonl"), atomically: true, encoding: .utf8)

// 4. Copies de travail à 1280 px (téléchargées depuis iCloud si besoin)
let reste = photos.filter { !FileManager.default.fileExists(atPath: dossier.appendingPathComponent(nomFichier($0)).path) }
print("photos depuis \(config["date_min"]!) : \(photos.count) | déjà copiées : \(photos.count - reste.count) | à copier : \(reste.count)")
let req = PHImageRequestOptions()
req.isSynchronous = true
req.isNetworkAccessAllowed = true
req.deliveryMode = .highQualityFormat
req.version = .current
let verrou = NSLock()
var faites = 0, erreurs = 0
DispatchQueue.concurrentPerform(iterations: reste.count) { i in
    let a = reste[i]
    var ok = false
    PHImageManager.default().requestImageDataAndOrientation(for: a, options: req) { data, _, _, _ in
        guard let data, let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,      // applique l'orientation
                kCGImageSourceThumbnailMaxPixelSize: 1280] as CFDictionary) else { return }
        let url = dossier.appendingPathComponent(nomFichier(a))
        if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
            ok = CGImageDestinationFinalize(dest)
        }
    }
    verrou.lock()
    faites += 1
    if !ok { erreurs += 1 }
    if faites % 200 == 0 { print("\(faites) / \(reste.count)") }
    verrou.unlock()
}
print("fini : \(reste.count - erreurs) photos copiées, \(erreurs) erreurs")

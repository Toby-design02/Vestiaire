"""Étape 5 (locale, gratuite) : met le résultat au format de l'app (docs/modele-de-donnees.md).
Sortie : out/app/dressing.json  {"items": [Item], "sessions": [Session], "wearEvents": [WearEvent]}
         out/app/images/        photos produit (pNNN.png) ; à défaut, la meilleure découpe (pNNN.jpg)
Les clés et les types suivent les structures Codable de l'app (Item, Session, WearEvent), plus "sourceImageNames" (vraies photos de la pièce, découpées) et "alternativeImageNames"
(variantes de la photo produit après fusion de doublons, ignoré par l'app tant qu'elle ne le lit pas) :
décodable avec JSONDecoder et dateDecodingStrategy = .iso8601.
Ces fichiers contiennent des données personnelles : ils restent dans out/ (exclu de GitHub)."""
import os, sys, json, uuid, shutil
from datetime import datetime
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, D, O, est_mode

PIECES = json.load(open(os.path.join(D, "pieces.json")))
SESS = {s["id"]: s for s in json.load(open(os.path.join(D, "sessions.json")))}
OUT = os.path.join(O, "app"); IMG = os.path.join(OUT, "images")
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(IMG)
# choix de l'utilisateur parmi les variantes d'une photo produit : {"p002": 1} = la 2e variante (0 = celle par défaut)
CHOIX = json.load(open(os.path.join(D, "choix_photos.json"))) if os.path.exists(os.path.join(D, "choix_photos.json")) else {}

NS = uuid.UUID("6f1c2e1a-5b7d-4c1e-9a43-7e0d3c2b9f10")       # identifiants stables d'un export à l'autre
def uid(x): return str(uuid.uuid5(NS, x)).upper()
RAYON = {"veste": "outerwear", "pull": "knitwear", "haut": "baseLayer", "bas": "bottoms",
         "chaussures": "shoes", "accessoire": "accessories"}
ANGLE = {"face": "front", "face_pied": "front", "profil": "side", "profil_pied": "side", "sans_visage": "back"}

def iso(dt):  # "2024:05:03 14:22:10" → "2024-05-03T14:22:10Z" (heure locale de la photo, notée telle quelle)
    return datetime.strptime(dt[:19], "%Y:%m:%d %H:%M:%S").strftime("%Y-%m-%dT%H:%M:%SZ")

def couleur_hex(path):
    """Couleur principale : médiane du centre de la découpe (évite le fond sur les bords)."""
    try:
        im = Image.open(os.path.join(R, path)).convert("RGB"); W, H = im.size
        a = np.array(im.crop((W // 4, H // 4, 3 * W // 4, 3 * H // 4))).reshape(-1, 3)
        return "#%02X%02X%02X" % tuple(int(v) for v in np.median(a, 0))
    except Exception:
        return "#888888"

def txt(v): return v if isinstance(v, str) and v.strip() and v.strip().lower() not in ("aucun", "none", "null", "-") else None

items, wears, used, pending = [], [], set(), []
for p in PIECES:
    if p.get("statut") in ("pas_a_moi", "fusionnee") or not est_mode(p): continue
    image = None
    photos = [f for f in [p.get("photo_produit")] + p.get("photos_alternatives", []) if f and os.path.exists(os.path.join(R, f))]
    if p["id"] in CHOIX and CHOIX[p["id"]] < len(photos): photos.insert(0, photos.pop(CHOIX[p["id"]]))   # variante choisie
    alternatives = []
    if photos:
        image = p["id"] + ".png"; shutil.copy(os.path.join(R, photos[0]), os.path.join(IMG, image))
        for k, f in enumerate(photos[1:], 1):
            alternatives.append(f"{p['id']}_v{k}.png"); shutil.copy(os.path.join(R, f), os.path.join(IMG, alternatives[-1]))
    elif p.get("decoupes"):
        image = p["id"] + ".jpg"; shutil.copy(os.path.join(R, p["decoupes"][0]), os.path.join(IMG, image))
    sources, vus = [], set()
    for sid in p["seances"]:
        for v in SESS[sid]["vues"]:
            if v.get("id_photo") and v["id_photo"] not in vus and len(sources) < 6:
                vus.add(v["id_photo"]); sources.append({"angle": ANGLE.get(v["angle"], "front"), "assetIdentifier": v["id_photo"]})
    vraies = []                       # vraies photos de la pièce (découpes), pour lever un doute sur la photo produit
    for k, f in enumerate(p.get("decoupes") or []):
        if os.path.exists(os.path.join(R, f)):
            vraies.append(f"{p['id']}_photo{k + 1}.jpg"); shutil.copy(os.path.join(R, f), os.path.join(IMG, vraies[-1]))
    marque = txt(p.get("marque"))
    fiche = {
        "id": uid(p["id"]), "pipelineID": p["id"], "category": RAYON.get((p.get("rayon") or "").lower(), "accessories"),
        "type": txt(p.get("type")) or (p.get("rayon") or "Pièce").capitalize(),
        "colors": p.get("couleurs") or [], "colorHex": couleur_hex(p["decoupes"][0]) if p.get("decoupes") else "#888888",
        "pattern": txt(p.get("motif")), "material": txt(p.get("matiere")), "fit": None, "collar": txt(p.get("coupe_col")),
        "frontDetails": txt(p.get("details_face")), "backDetails": txt(p.get("details_dos")),
        "detectedTexts": [txt(p.get("logos_textes"))] if txt(p.get("logos_textes")) else [],
        "brand": {"name": marque, "model": None, "confidence": 0.6, "source": "photo"} if marque else None,
        "pricePaid": p.get("prix_paye"), "priceNew": p.get("prix_neuf"), "resaleValue": p.get("valeur_revente"),
        "status": "active", "productImageName": image, "alternativeImageNames": alternatives, "sourceImageNames": vraies, "sourcePhotos": sources,
        "openToOffers": False, "openToSwap": False, "isFavorite": False, "seasons": [], "occasions": [], "tagIDs": []}
    if not photos:                    # sans photo produit : « à confirmer », hors du dressing (souvent un fragment de photo)
        fiche["pendingReason"] = p.get("photos_insuffisantes") or "pas de photo produit"; pending.append(fiche); continue
    items.append(fiche)
    for sid in p["seances"]:
        used.add(sid)
        wears.append({"id": uid(p["id"] + sid), "itemID": uid(p["id"]), "sessionID": uid(sid), "date": iso(SESS[sid]["debut"])})

sessions = [{"id": uid(sid), "date": iso(SESS[sid]["debut"]), "place": None, "context": "everyday",
             "photoCount": SESS[sid]["nb_photos"], "origin": "gallery", "photo": None, "samplePhotoName": None,
             "outfitID": None, "isSample": False} for sid in sorted(used)]

pending.sort(key=lambda f: -len(f["sourceImageNames"]))
json.dump({"items": items, "sessions": sessions, "wearEvents": wears, "pendingItems": pending},
          open(os.path.join(OUT, "dressing.json"), "w"), ensure_ascii=False, indent=1)
print(len(items), "pièces |", sum(1 for i in items if (i["productImageName"] or "").endswith(".png")), "avec photo produit |", len(pending), "à confirmer |",
      len(sessions), "séances |", len(wears), "ports →", os.path.relpath(OUT, R))

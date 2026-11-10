"""Étape 5 (locale, gratuite) : met le résultat au format de l'app (docs/modele-de-donnees.md).
Sortie : out/app/dressing.json  {"items": [Item], "sessions": [Session], "wearEvents": [WearEvent]}
         out/app/images/        photos produit (pNNN.png) ; à défaut, la meilleure découpe (pNNN.jpg)
Les clés et les types suivent les structures Codable de l'app (Item, Session, WearEvent) :
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

items, wears, used = [], [], set()
for p in PIECES:
    if p.get("statut") in ("pas_a_moi", "fusionnee") or not est_mode(p): continue
    image = None
    if p.get("photo_produit") and os.path.exists(os.path.join(R, p["photo_produit"])):
        image = p["id"] + ".png"; shutil.copy(os.path.join(R, p["photo_produit"]), os.path.join(IMG, image))
    elif p.get("decoupes"):
        image = p["id"] + ".jpg"; shutil.copy(os.path.join(R, p["decoupes"][0]), os.path.join(IMG, image))
    sources, vus = [], set()
    for sid in p["seances"]:
        for v in SESS[sid]["vues"]:
            if v.get("id_photo") and v["id_photo"] not in vus and len(sources) < 6:
                vus.add(v["id_photo"]); sources.append({"angle": ANGLE.get(v["angle"], "front"), "assetIdentifier": v["id_photo"]})
    marque = txt(p.get("marque"))
    items.append({
        "id": uid(p["id"]), "category": RAYON.get((p.get("rayon") or "").lower(), "accessories"),
        "type": txt(p.get("type")) or (p.get("rayon") or "Pièce").capitalize(),
        "colors": p.get("couleurs") or [], "colorHex": couleur_hex(p["decoupes"][0]) if p.get("decoupes") else "#888888",
        "pattern": txt(p.get("motif")), "material": txt(p.get("matiere")), "fit": None, "collar": txt(p.get("coupe_col")),
        "frontDetails": txt(p.get("details_face")), "backDetails": txt(p.get("details_dos")),
        "detectedTexts": [txt(p.get("logos_textes"))] if txt(p.get("logos_textes")) else [],
        "brand": {"name": marque, "model": None, "confidence": 0.6, "source": "photo"} if marque else None,
        "pricePaid": p.get("prix_paye"), "priceNew": p.get("prix_neuf"), "resaleValue": p.get("valeur_revente"),
        "status": "active", "productImageName": image, "sourcePhotos": sources,
        "openToOffers": False, "openToSwap": False, "isFavorite": False, "seasons": [], "occasions": [], "tagIDs": []})
    for sid in p["seances"]:
        used.add(sid)
        wears.append({"id": uid(p["id"] + sid), "itemID": uid(p["id"]), "sessionID": uid(sid), "date": iso(SESS[sid]["debut"])})

sessions = [{"id": uid(sid), "date": iso(SESS[sid]["debut"]), "place": None, "context": "everyday",
             "photoCount": SESS[sid]["nb_photos"], "origin": "gallery", "photo": None, "samplePhotoName": None,
             "outfitID": None, "isSample": False} for sid in sorted(used)]

json.dump({"items": items, "sessions": sessions, "wearEvents": wears},
          open(os.path.join(OUT, "dressing.json"), "w"), ensure_ascii=False, indent=1)
print(len(items), "pièces |", sum(1 for i in items if (i["productImageName"] or "").endswith(".png")), "avec photo produit |",
      len(sessions), "séances |", len(wears), "ports →", os.path.relpath(OUT, R))

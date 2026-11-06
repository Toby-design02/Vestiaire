"""Étape 1b (locale, gratuite) : reconnaît l'utilisateur, regroupe par séance, classe les angles
(face, profil, plein pied, sans visage), rattache les photos sans visage qui montrent la même tenue,
et garde les meilleures vues par séance.
Sortie : data/sessions.json + out/crops/*.jpg (recadrages basse résolution : les seules images envoyées aux API)."""
import os, sys, json, numpy as np, cv2
from datetime import datetime
from collections import Counter
from PIL import Image, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, photos_dir, galerie

PH = photos_dir()
GAL = galerie()
CROPS = os.path.join(R, "out", "crops"); os.makedirs(CROPS, exist_ok=True)

def cos(a, b): return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))

rows, seen = [], set()
for l in open(os.path.join(R, "data", "detections.jsonl")):
    try: r = json.loads(l)
    except ValueError: continue
    if r.get("skip") or r.get("err") or not r.get("dt"): continue
    k = (r["dt"], tuple(r["wh"]), r["sharp"])          # doublons d'export « (1) »
    if k in seen: continue
    seen.add(k)
    try: r["t"] = datetime.strptime(r["dt"][:19], "%Y:%m:%d %H:%M:%S")
    except ValueError: continue
    rows.append(r)

# 1. Visage de référence. Avec selfie.jpg (comme l'onboarding de l'app) : le visage du selfie,
#    affiné par ses photos les plus ressemblantes de la galerie (autres angles, autres lumières).
#    Sans selfie : le plus grand groupe de visages nets et seuls sur la photo (risqué sur une galerie entière).
allf = [np.array(f["emb"]) for r in rows for f in r["faces"]]
SELFIE = os.path.join(R, "selfie.jpg")
if os.path.exists(SELFIE):
    from detect import faces
    try: from pillow_heif import register_heif_opener; register_heif_opener()   # selfie au format iPhone (HEIC)
    except ImportError: pass
    im = ImageOps.exif_transpose(Image.open(SELFIE)).convert("RGB"); im.thumbnail((1280, 1280))
    fs = faces(cv2.cvtColor(np.array(im), cv2.COLOR_RGB2BGR))
    if not fs: raise SystemExit("Aucun visage trouvé dans selfie.jpg : prends un selfie de face, bien éclairé.")
    me = np.array(max(fs, key=lambda f: (f["b"][2] - f["b"][0]) * (f["b"][3] - f["b"][1]))["emb"])
    proches = [e for e in allf if cos(me, e) > 0.50]
    ref = np.mean([me] * max(1, len(proches) // 2) + proches, 0) if len(proches) >= 5 else me
    print("selfie : visage trouvé,", len(proches), "photos très ressemblantes dans la galerie")
else:
    cand = [np.array(f["emb"]) for r in rows if len(r["faces"]) == 1 for f in r["faces"] if f["s"] > 0.9 and f["b"][2] - f["b"][0] > 0.08]
    ref = None
    for e in cand[:400]:
        n = sum(cos(e, c) > 0.45 for c in cand)
        if ref is None or n > ref[1]: ref = (e, n)
    ref = np.mean([c for c in cand if cos(ref[0], c) > 0.45], 0)
    for _ in range(2):
        ref = np.mean([e for e in allf if cos(ref, e) > 0.42], 0)

def inside(fb, pb):
    cx, cy = (fb[0] + fb[2]) / 2, (fb[1] + fb[3]) / 2
    return pb[0] <= cx <= pb[2] and pb[1] <= cy <= pb[3]

# 2. Sur chaque photo : quelle personne est l'utilisateur, et sous quel angle
for r in rows:
    r["me"] = None
    best = max(r["faces"], key=lambda f: cos(ref, np.array(f["emb"])), default=None)
    if best and cos(ref, np.array(best["emb"])) >= 0.40:
        boxes = [p for p in r["persons"] if inside(best["b"], p)]
        if boxes:
            pb = min(boxes, key=lambda p: (p[2] - p[0]) * (p[3] - p[1]))
            r["me"] = {"box": pb[:4], "angle": "face" if best["eye"] >= 0.30 else "profil",
                       "sim": round(cos(ref, np.array(best["emb"])), 3), "fb": best["b"]}
    r["nofaceperson"] = [p for p in r["persons"] if not any(inside(f["b"], p) for f in r["faces"])
                         and (p[2] - p[0]) * (p[3] - p[1]) > 0.04]

# 3. Séances : même jour, moins de N heures entre deux photos
rows.sort(key=lambda r: r["t"])
sess, cur = [], []
for r in rows:
    if cur and ((r["t"] - cur[-1]["t"]).total_seconds() > CFG["seance_ecart_heures"] * 3600 or r["t"].date() != cur[-1]["t"].date()):
        sess.append(cur); cur = []
    cur.append(r)
if cur: sess.append(cur)

def load(f):
    im = ImageOps.exif_transpose(Image.open(os.path.join(PH, f))).convert("RGB"); im.thumbnail((1600, 1600)); return im

def torso_hist(im, b):
    W, H = im.size; x0, y0, x1, y1 = b
    c = np.array(im.crop((int(W * x0), int(H * (y0 + 0.25 * (y1 - y0))), int(W * x1), int(H * (y0 + 0.6 * (y1 - y0))))))
    if c.size == 0: return None
    h = cv2.calcHist([cv2.cvtColor(c, cv2.COLOR_RGB2HSV)], [0, 1], None, [18, 8], [0, 180, 0, 256])
    return cv2.normalize(h, h).flatten()

def tall(r, b): return (b[3] - b[1]) * r["wh"][1] / max((b[2] - b[0]) * r["wh"][0], 1) >= 2.0

def score(r, b):
    return (b[2] - b[0]) * (b[3] - b[1]) * min(1.0, r["sharp"] / 150) * (1.3 if tall(r, b) else 1.0)

out, n_sans = [], 0
for si, S in enumerate(sess):
    mine = [r for r in S if r["me"]]
    if not mine: continue
    top = max(mine, key=lambda r: score(r, r["me"]["box"]))
    ref_h = torso_hist(load(top["f"]), top["me"]["box"])
    # photos sans visage : une personne dont le torse a les mêmes couleurs que l'utilisateur dans la séance
    sans = []
    for r in S:
        if r["me"] or not r["nofaceperson"] or ref_h is None: continue
        im = None
        for p in sorted(r["nofaceperson"], key=lambda p: -(p[2] - p[0]) * (p[3] - p[1]))[:3]:
            im = im or load(r["f"]); h = torso_hist(im, p[:4])
            if h is None: continue
            d = cv2.compareHist(ref_h, h, cv2.HISTCMP_BHATTACHARYYA)
            if d < 0.30 and (p[3] - p[1]) >= 0.45: sans.append((score(r, p[:4]) * (1 - d), r, p[:4])); break
    views = [(score(r, r["me"]["box"]), r, r["me"]["box"], r["me"]["angle"]) for r in mine]
    pick = []
    if sans:
        _, r, b = max(sans, key=lambda x: x[0]); pick.append((r, b, "sans_visage")); n_sans += 1
    full = [v for v in views if tall(v[1], v[2])]
    if full:
        v = max(full, key=lambda v: v[0]); pick.append((v[1], v[2], v[3] + "_pied"))
    for v in sorted(views, key=lambda v: -v[0]):
        if len(pick) >= CFG["vues_max_par_seance"]: break
        if all(v[1]["f"] != p[0]["f"] for p in pick): pick.append((v[1], v[2], v[3]))
    entry = {"id": f"s{si:04d}", "debut": S[0]["dt"], "nb_photos": len(S), "vues": []}
    for k, (r, b, ang) in enumerate(pick[:CFG["vues_max_par_seance"]]):
        im = load(r["f"]); W, H = im.size; mx, my = 0.06 * (b[2] - b[0]), 0.04 * (b[3] - b[1])
        c = im.crop((int(W * max(0, b[0] - mx)), int(H * max(0, b[1] - my)), int(W * min(1, b[2] + mx)), int(H * min(1, b[3] + my))))
        c.thumbnail((CFG["recadrage_cote_long_px"],) * 2)
        cp = os.path.join(CROPS, f"{entry['id']}_{k}_{ang}.jpg"); c.save(cp, quality=85)
        entry["vues"].append({"photo": r["f"], "sim": (r["me"] or {}).get("sim"), "boite": [round(x, 3) for x in b], "fb": (r["me"] or {}).get("fb"), "id_photo": GAL.get(r["f"], {}).get("id"), "angle": ang, "recadrage": os.path.relpath(cp, R)})
    out.append(entry)

json.dump(out, open(os.path.join(R, "data", "sessions.json"), "w"), ensure_ascii=False, indent=1)
print("photos", len(rows), "| avec l'utilisateur", sum(1 for r in rows if r["me"]), "| séances", len(out),
      "| vues", sum(len(e["vues"]) for e in out), "| séances avec une vue sans visage", n_sans)
print(Counter(v["angle"] for e in out for v in e["vues"]))

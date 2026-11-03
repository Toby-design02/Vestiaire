"""Étape 3 : fusionne les pièces vues dans plusieurs séances en une seule fiche.
Gratuit (code) dans la grande majorité des cas ; un petit appel Haiku à 2 images seulement quand c'est ambigu.
Usage : python3 algo/dedoublonnage.py
Sortie : data/pieces.json (+ out/pieces/<id>_<k>.jpg, les meilleures découpes de chaque pièce)."""
import os, sys, json, base64, io
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, charge, guard, TARIFS

SESS = {s["id"]: s for s in json.load(open(os.path.join(R, "data", "sessions.json")))}
LECT = json.load(open(os.path.join(R, "data", "lecture.json")))
OUTD = os.path.join(R, "out", "pieces"); os.makedirs(OUTD, exist_ok=True)
MODEL = CFG["modeles"]["arbitrage"]
MAX_ARBITRAGES = 60          # garde-fou : au-delà, on garde les pièces séparées (l'utilisateur fusionnera dans l'app)

def norm(s): return (s or "").lower().strip()

def crop_of(sid, p):
    """Découpe la pièce dans le recadrage de la séance à partir de la boîte donnée par Haiku (millièmes)."""
    try:
        x0, y0, x1, y1, idx = p["boite"]; v = SESS[sid]["vues"][int(idx)]
        im = Image.open(os.path.join(R, v["recadrage"])).convert("RGB"); W, H = im.size
        c = im.crop((int(W * x0 / 1000), int(H * y0 / 1000), int(W * x1 / 1000), int(H * y1 / 1000)))
        return c if c.width > 24 and c.height > 24 else None, v["angle"]
    except Exception:
        return None, None

def hist(im):
    hsv = cv2.cvtColor(np.array(im.resize((96, 96))), cv2.COLOR_RGB2HSV)
    h = cv2.calcHist([hsv], [0, 1, 2], None, [12, 6, 4], [0, 180, 0, 256, 0, 256]); return cv2.normalize(h, h).flatten()

# 1. toutes les observations
obs = []
for sid, pieces in LECT.items():
    if not isinstance(pieces, list): continue
    for p in pieces:
        c, ang = crop_of(sid, p)
        obs.append({"sid": sid, "date": SESS[sid]["debut"][:10].replace(":", "-"), "p": p, "crop": c, "angle": ang,
                    "h": hist(c) if c else None,
                    "cle": (norm(p.get("rayon")), norm(p.get("motif")), norm((p.get("couleurs") or [""])[0]))})

def b64(im):
    b = io.BytesIO(); x = im.copy(); x.thumbnail((256, 256)); x.save(b, "JPEG", quality=80); return base64.b64encode(b.getvalue()).decode()

_cli, n_arb = None, 0
def meme_piece(a, b):
    """Arbitrage Haiku : 2 petites images, réponse oui/non. Environ 0,0001 $ l'appel."""
    global _cli, n_arb
    if n_arb >= MAX_ARBITRAGES or a["crop"] is None or b["crop"] is None: return False
    guard(0.0005, "arbitrage doublon")
    import anthropic
    _cli = _cli or anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    m = _cli.messages.create(model=MODEL, max_tokens=5, messages=[{"role": "user", "content": [
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64(a["crop"])}},
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64(b["crop"])}},
        {"type": "text", "text": "Est-ce exactement le même vêtement (même pièce, pas seulement le même style) ? Réponds oui ou non."}]}])
    n_arb += 1
    charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "arbitrage doublon")
    return "oui" in m.content[0].text.lower()

# 2. regroupement : même rayon + motif + couleur principale, puis ressemblance des couleurs de la découpe
pieces = []
for o in sorted(obs, key=lambda o: o["date"]):
    best, bd = None, 9
    for it in pieces:
        if it["cle"] != o["cle"]: continue
        if o["h"] is None or it["h"] is None: d = 0.4
        else: d = cv2.compareHist(it["h"], o["h"], cv2.HISTCMP_BHATTACHARYYA)
        lo, li = norm(o["p"].get("logos_textes")), norm(it["logos"])
        if lo and li and lo not in li and li not in lo: d += 0.3          # deux logos différents : pas la même pièce
        if d < bd: best, bd = it, d
    if best is not None and (bd < 0.30 or (bd < 0.50 and meme_piece(best["obs"][0], o))):
        best["obs"].append(o)
        if o["p"].get("logos_textes") and not best["logos"]: best["logos"] = o["p"]["logos_textes"]
    else:
        pieces.append({"cle": o["cle"], "h": o["h"], "logos": o["p"].get("logos_textes"), "obs": [o]})

# 3. fiche finale de chaque pièce
def plus_long(vals): vals = [v for v in vals if v]; return max(vals, key=len) if vals else None
out = []
for i, it in enumerate(sorted(pieces, key=lambda it: -len({o["sid"] for o in it["obs"]}))):
    ps = [o["p"] for o in it["obs"]]; dates = sorted({o["date"] for o in it["obs"]})
    # meilleures découpes : la plus grande par angle, 3 maximum, angles différents d'abord
    vues, angles = [], set()
    for o in sorted([o for o in it["obs"] if o["crop"]], key=lambda o: -o["crop"].width * o["crop"].height):
        if o["angle"] in angles and len(vues) < 2: continue
        angles.add(o["angle"]); k = len(vues); path = os.path.join(OUTD, f"p{i:03d}_{k}.jpg")
        o["crop"].save(path, quality=88); vues.append(os.path.relpath(path, R))
        if len(vues) == 3: break
    out.append({
        "id": f"p{i:03d}", "rayon": ps[0].get("rayon"), "type": plus_long([p.get("type") for p in ps]),
        "couleurs": ps[0].get("couleurs"), "motif": ps[0].get("motif"), "matiere": plus_long([p.get("matiere") for p in ps]),
        "coupe_col": plus_long([p.get("coupe_col") for p in ps]), "details_face": plus_long([p.get("details_face") for p in ps]),
        "details_dos": plus_long([p.get("details_dos") for p in ps]), "logos_textes": it["logos"],
        "marque": plus_long([p.get("marque_probable") for p in ps]), "marque_source": "photo" if any(p.get("marque_probable") for p in ps) else None,
        "prix_paye": None, "prix_neuf": None, "valeur_revente": None, "statut": "actif",
        "ports": len({o["sid"] for o in it["obs"]}), "seances": sorted({o["sid"] for o in it["obs"]}),
        "premiere_fois": dates[0], "derniere_fois": dates[-1], "decoupes": vues, "photo_produit": None})
json.dump(out, open(os.path.join(R, "data", "pieces.json"), "w"), ensure_ascii=False, indent=1)
print(len(obs), "observations →", len(out), "pièces |", sum(1 for p in out if p["ports"] >= CFG["ports_min_pour_generation"]),
      "portées au moins", CFG["ports_min_pour_generation"], "fois |", n_arb, "arbitrages Haiku")

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
MAX_ARBITRAGES = 250         # garde-fou : au-delà, on garde les pièces séparées (l'utilisateur fusionnera dans l'app)

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

# 1. toutes les observations, avec leur qualité : taille de la découpe, pièce entière ou non, logo lisible ou non
FAMILLE = {"veste": "dessus", "pull": "dessus"}         # un sweat zippé peut être lu « veste » un jour, « pull » un autre

def qualite(o):
    if o["crop"] is None: return 0
    w, h = o["crop"].size; q = min(1.0, (w * h) / 150000)
    if o["p"].get("visible") == "entier": q *= 2
    if o["p"].get("logos_textes"): q *= 1.5 if o["p"].get("logo_complet") is True else 0.5
    return q

obs = []
for sid, pieces in LECT.items():
    if not isinstance(pieces, list): continue
    for p in pieces:
        if (p.get("confiance") or 1) < 0.5: continue          # pièce trop peu visible pour être décrite
        c, ang = crop_of(sid, p); r = norm(p.get("rayon"))
        o = {"sid": sid, "date": SESS[sid]["debut"][:10].replace(":", "-"), "p": p, "crop": c, "angle": ang,
             "h": hist(c) if c else None, "fam": FAMILLE.get(r, r)}
        o["q"] = qualite(o); obs.append(o)

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
    try:
        m = _cli.messages.create(model=MODEL, max_tokens=20, messages=[{"role": "user", "content": [
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64(a["crop"])}},
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64(b["crop"])}},
        {"type": "text", "text": "Est-ce exactement le même vêtement (même pièce, pas seulement le même style) ? Réponds oui ou non."}]}])
    except Exception as e:
        print("arbitrage impossible, pièces gardées séparées :", str(e)[:120]); return False
    n_arb += 1
    charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "arbitrage doublon")
    return "oui" in "".join(x.text for x in m.content if x.type == "text").lower()

# 2. regroupement : on part des meilleures photos, puis chaque observation rejoint la pièce
#    dont les couleurs réelles (pas le texte) sont les plus proches ; Haiku tranche les cas douteux.
def logos_incompatibles(a, b):
    la, lb = norm(a["p"].get("logos_textes")).replace("…", ""), norm(b["p"].get("logos_textes")).replace("…", "")
    if not la or not lb: return False
    return la not in lb and lb not in la and not (a["p"].get("logo_complet") is False or b["p"].get("logo_complet") is False)

pieces = []
for o in sorted(obs, key=lambda o: -o["q"]):
    best, bd = None, 9
    for it in pieces:
        if it["fam"] != o["fam"]: continue
        refs = [x for x in it["obs"][:6] if x["h"] is not None]
        if o["h"] is None or not refs: d = 0.4
        else: d = min(cv2.compareHist(x["h"], o["h"], cv2.HISTCMP_BHATTACHARYYA) for x in refs)
        if logos_incompatibles(it["obs"][0], o): d += 0.3
        if d < bd: best, bd = it, d
    if best is not None and (bd < 0.25 or (bd < 0.45 and meme_piece(best["obs"][0], o))):
        best["obs"].append(o)
    else:
        pieces.append({"fam": o["fam"], "obs": [o]})

# 3. fiche finale de chaque pièce
from collections import Counter
def plus_long(vals): vals = [v for v in vals if v]; return max(vals, key=len) if vals else None
def vote(vals): vals = [v for v in vals if v]; return Counter(vals).most_common(1)[0][0] if vals else None
TAILLE_MIN = (160, 60000)        # côté minimum, surface minimum (px) d'une découpe utilisable pour générer

def utilisable(o):
    return o["crop"] is not None and min(o["crop"].size) >= TAILLE_MIN[0] and o["crop"].width * o["crop"].height >= TAILLE_MIN[1]

out = []
for i, it in enumerate(sorted(pieces, key=lambda it: -len({o["sid"] for o in it["obs"]}))):
    O = sorted(it["obs"], key=lambda o: -o["q"]); ps = [o["p"] for o in O]; dates = sorted({o["date"] for o in O})
    a_logo = any(p.get("logos_textes") for p in ps)
    logo_ok = [o for o in O if o["p"].get("logos_textes") and o["p"].get("logo_complet") is True]
    entieres = [o for o in O if o["p"].get("visible") == "entier" and utilisable(o)]
    # photos envoyées au générateur : les meilleures, en cherchant le plus d'angles différents (face, profil, dos)
    bonnes = [o for o in O if utilisable(o) and not (logo_ok and o["p"].get("logo_complet") is False)]   # pas de logo coupé s'il existe en entier
    choix = []
    for o in bonnes:                                     # 1er passage : un angle différent à chaque fois
        if len(choix) < 3 and o["angle"] not in {c["angle"] for c in choix}: choix.append(o)
    for o in bonnes:                                     # 2e passage : compléter avec les meilleures restantes
        if len(choix) < 3 and o not in choix: choix.append(o)
    vues = []
    for k, o in enumerate(choix or O[:1]):
        if o["crop"] is None: continue
        path = os.path.join(OUTD, f"p{i:03d}_{k}.jpg"); o["crop"].save(path, quality=90); vues.append(os.path.relpath(path, R))
    # génération seulement sans doute évident
    if not entieres: raison = "aucune photo où la pièce est entière"
    elif a_logo and not logo_ok: raison = "logo ou texte toujours partiellement caché"
    else: raison = None
    out.append({
        "id": f"p{i:03d}", "rayon": vote([p.get("rayon") for p in ps]), "type": vote([p.get("type") for p in ps]),
        "couleurs": ps[0].get("couleurs"), "motif": vote([p.get("motif") for p in ps]), "matiere": vote([p.get("matiere") for p in ps]),
        "coupe_col": plus_long([p.get("coupe_col") for p in ps[:3]]), "details_face": plus_long([p.get("details_face") for p in ps[:3]]),
        "details_dos": plus_long([p.get("details_dos") for p in ps]),
        "logos_textes": (logo_ok[0]["p"]["logos_textes"] if logo_ok else plus_long([p.get("logos_textes") for p in ps])),
        "logo_complet": bool(logo_ok) if a_logo else None,
        "marque": vote([p.get("marque_probable") for p in ps]), "marque_source": "photo" if any(p.get("marque_probable") for p in ps) else None,
        "prix_paye": None, "prix_neuf": None, "valeur_revente": None, "statut": "actif",
        "ports": len({o["sid"] for o in O}), "seances": sorted({o["sid"] for o in O}), "nb_photos": len(O),
        "angles": sorted({o["angle"] for o in O if o["angle"]}),
        "premiere_fois": dates[0], "derniere_fois": dates[-1], "decoupes": vues,
        "generable": raison is None, "photos_insuffisantes": raison, "photo_produit": None})
json.dump(out, open(os.path.join(R, "data", "pieces.json"), "w"), ensure_ascii=False, indent=1)
print(len(obs), "observations →", len(out), "pièces |", sum(1 for p in out if p["ports"] >= CFG["ports_min_pour_generation"]),
      "portées au moins", CFG["ports_min_pour_generation"], "fois |", sum(p["generable"] for p in out), "avec des photos suffisantes |", n_arb, "arbitrages Haiku")

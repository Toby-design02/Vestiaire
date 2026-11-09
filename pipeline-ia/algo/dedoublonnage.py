"""Étape 3 : regroupe les photos d'une même pièce vue dans plusieurs séances, puis choisit ses meilleures vues.
1. En local (gratuit) : une empreinte visuelle de chaque découpe (réseau MobileNet) + sa couleur réelle,
   pour trouver les photos qui se ressemblent le plus.
2. Haiku confirme : une planche de 16 photos, la n°1 étant la référence (≈ 0,0001 $ la planche).
Usage : python3 algo/dedoublonnage.py            (python3 algo/dedoublonnage.py --estimer : compte les planches, sans appel ni écriture)
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
CANDIDATS = 15               # photos montrées à Haiku à côté de la référence
SIM_MIN = 0.35               # en dessous, aucune photo n'est assez proche : pièce seule, sans appel

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

_net = cv2.dnn.readNet(os.path.join(R, "models", "image_classification_mobilenetv2_2022apr.onnx"))
def empreinte(im):
    """Empreinte visuelle (forme, matière, texture) : sortie du réseau MobileNet, normalisée."""
    a = (np.array(im.resize((224, 224))).astype(np.float32) / 255 - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    _net.setInput(a.transpose(2, 0, 1)[None].astype(np.float32)); v = _net.forward().flatten()
    return v / (np.linalg.norm(v) + 1e-9)

def couleur(im):
    """Couleur réelle au centre de la découpe, en Lab (proche de la perception)."""
    a = cv2.cvtColor(np.array(im.resize((48, 48)))[12:36, 12:36], cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(float)
    return np.median(a, 0)

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
             "fam": FAMILLE.get(r, r)}
        if c is None: continue
        o["q"] = qualite(o); o["e"] = empreinte(c); o["c"] = couleur(c); obs.append(o)

# 2. regroupement : la meilleure photo pas encore classée sert de référence ; on montre à Haiku
#    ses 15 voisines les plus proches (empreinte + couleur), et il dit lesquelles sont la même pièce.
from PIL import ImageDraw, ImageFont
from concurrent.futures import ThreadPoolExecutor
from common import prompt
import threading
_cli, n_planches, _verrou = None, 0, threading.Lock()
ESTIMER = "--estimer" in sys.argv

def planche(liste):
    T = 200; im = Image.new("RGB", (4 * T, 4 * T), "white"); d = ImageDraw.Draw(im)
    try: f = ImageFont.load_default(size=30)
    except Exception: f = ImageFont.load_default()
    for k, o in enumerate(liste):
        c = o["crop"].copy(); c.thumbnail((T - 6, T - 6)); X, Y = (k % 4) * T, (k // 4) * T
        im.paste(c, (X + 3, Y + 3)); d.rectangle([X, Y, X + 44, Y + 34], fill="white"); d.text((X + 4, Y + 1), str(k + 1), fill="red", font=f)
    b = io.BytesIO(); im.save(b, "JPEG", quality=82); return base64.b64encode(b.getvalue()).decode()

def memes(ref, cands, fam):
    """Numéros (dans cands) que Haiku reconnaît comme la même pièce que ref."""
    global _cli, n_planches
    if ESTIMER:
        with _verrou: n_planches += 1
        return []
    import anthropic
    with _verrou:
        guard(0.0005, "regroupement des pièces"); _cli = _cli or anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    txt = prompt("textes/T2_meme_piece.md", n=len(cands) + 1, famille=fam)
    for essai in range(3):
        try:
            m = _cli.messages.create(model=MODEL, max_tokens=60, messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": planche([ref] + cands)}},
                {"type": "text", "text": txt}]}])
            break
        except Exception as e:
            err = e
    else:
        print("regroupement impossible pour une pièce, gardée seule :", str(err)[:120]); return []
    with _verrou:
        n_planches += 1
        charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "regroupement (planche)")
    t = "".join(x.text for x in m.content if x.type == "text")
    try: nums = json.loads(t[t.find("{"): t.rfind("}") + 1]).get("memes", [])
    except Exception: return []
    return [cands[n - 2] for n in nums if isinstance(n, int) and 2 <= n <= len(cands) + 1]

def regrouper(fam, liste):
    reste = sorted(liste, key=lambda o: -o["q"]); groupes = []
    while reste:
        ref = reste.pop(0); groupe = [ref]
        if reste:
            sim = np.array([float(o["e"] @ ref["e"]) - np.linalg.norm(o["c"] - ref["c"]) / 120 for o in reste])
            idx = [i for i in np.argsort(-sim) if sim[i] >= SIM_MIN and reste[i]["sid"] != ref["sid"]][:CANDIDATS]
            if idx:
                for o in memes(ref, [reste[i] for i in idx], fam):
                    if o["sid"] not in {g["sid"] for g in groupe}: groupe.append(o)   # une pièce n'apparaît qu'une fois par séance
                reste = [o for o in reste if o not in groupe]
        groupes.append({"fam": fam, "obs": groupe})
    print(f"  {fam} : {len(liste)} photos → {len(groupes)} pièces", flush=True)
    return groupes

familles = {}
for o in obs: familles.setdefault(o["fam"], []).append(o)
print(len(obs), "photos de pièces à regrouper", flush=True)
with ThreadPoolExecutor(6) as ex:
    pieces = [g for gs in ex.map(lambda kv: regrouper(*kv), familles.items()) for g in gs]

if ESTIMER:
    print(n_planches, "planches Haiku au maximum, soit ≈", round(n_planches * 0.00012, 3), "$"); raise SystemExit

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
      "portées au moins", CFG["ports_min_pour_generation"], "fois |", sum(p["generable"] for p in out), "avec des photos suffisantes |", n_planches, "planches Haiku")

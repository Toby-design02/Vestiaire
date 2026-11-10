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
from common import R, CFG, env, charge, guard, TARIFS, D, O as SORTIES

SESS = {s["id"]: s for s in json.load(open(os.path.join(D, "sessions.json")))}
LECT = json.load(open(os.path.join(D, "lecture.json")))
OUTD = os.path.join(SORTIES, "pieces"); os.makedirs(OUTD, exist_ok=True)
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
    for j, p in enumerate(pieces):
        if (p.get("confiance") or 1) < 0.5: continue          # pièce trop peu visible pour être décrite
        c, ang = crop_of(sid, p); r = norm(p.get("rayon"))
        o = {"id": f"{sid}#{j}", "sid": sid, "date": SESS[sid]["debut"][:10].replace(":", "-"), "p": p, "crop": c, "angle": ang,
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
TEST = int(sys.argv[sys.argv.index("--test") + 1]) if "--test" in sys.argv else 0   # --test N : N planches seulement, enregistrées dans data/
LOG = open(os.path.join(D, "regroupement_log.jsonl"), "w")
import re

def planche(liste):
    b = io.BytesIO(); planche_img(liste).save(b, "JPEG", quality=82); return base64.b64encode(b.getvalue()).decode()

def planche_img(liste):
    T = 200; im = Image.new("RGB", (4 * T, 4 * T), "white"); d = ImageDraw.Draw(im)
    try: f = ImageFont.load_default(size=30)
    except Exception: f = ImageFont.load_default()
    for k, o in enumerate(liste):
        c = o["crop"].copy(); c.thumbnail((T - 6, T - 6)); X, Y = (k % 4) * T, (k // 4) * T
        im.paste(c, (X + 3, Y + 3)); d.rectangle([X, Y, X + 44, Y + 34], fill="white"); d.text((X + 4, Y + 1), str(k + 1), fill="red", font=f)
    return im

CACHE_F = os.path.join(D, "cache_planches.json")
CACHE = json.load(open(CACHE_F)) if os.path.exists(CACHE_F) else {}   # réponses déjà payées : une relance ne les repaie pas

def memes(ref, cands, fam):
    """Unités (dans cands) que Haiku reconnaît comme la même pièce que ref."""
    global _cli, n_planches
    cle = ref["id"] + "|" + ",".join(c["id"] for c in cands)
    if cle in CACHE: return [c for c in cands if c["id"] in CACHE[cle]]
    if ESTIMER or (TEST and n_planches >= TEST):
        with _verrou: n_planches += 1
        return []
    import anthropic
    with _verrou:
        guard(0.0005, "regroupement des pièces"); _cli = _cli or anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    txt = prompt("textes/T2_meme_piece.md", n=len(cands) + 1, famille=fam)
    for essai in range(3):
        try:
            m = _cli.messages.create(model=MODEL, max_tokens=1500, extra_body={"output_config": {"effort": "low"}}, messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": planche([ref] + cands)}},
                {"type": "text", "text": txt}]}])
            break
        except Exception as e:
            err = e
    else:
        print("regroupement impossible pour une pièce, gardée seule :", str(err)[:120]); return []
    t = "".join(x.text for x in m.content if x.type == "text")
    try: nums = [int(n) for n in json.loads(t[t.find("{"): t.rfind("}") + 1]).get("memes", [])]
    except Exception: nums = [int(n) for n in re.findall(r"\d+", t)] if "memes" in t else []
    res = [cands[n - 2] for n in nums if 2 <= n <= len(cands) + 1]
    with _verrou:
        n_planches += 1
        charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "regroupement (planche)")
        CACHE[cle] = [c["id"] for c in res]
        if n_planches % 20 == 0: json.dump(CACHE, open(CACHE_F, "w"))
        LOG.write(json.dumps({"ref": ref["id"], "fam": fam, "reponse": t[:300], "stop": m.stop_reason, "tokens_sortie": m.usage.output_tokens}, ensure_ascii=False) + "\n"); LOG.flush()
        if TEST: planche_img([ref] + cands).save(os.path.join(D, f"planche_test_{n_planches}.jpg"), quality=80)
    return res

def nette(u): return min(u["crop"].size) >= 160 and u["crop"].width * u["crop"].height >= 60000

def regrouper(fam, unites):
    """Unité = une photo de pièce (1er passage) ou un groupe déjà formé (2e passage, représenté par sa meilleure photo).
    La meilleure unité pas encore classée sert de référence ; Haiku dit lesquelles de ses 15 voisines sont la même pièce."""
    reste = sorted(unites, key=lambda u: (-len(u["obs"]), -u["q"])); groupes = []
    while reste:
        ref = reste.pop(0); groupe = [ref]
        # seule une photo nette sert de référence (les petites découpes peuvent rejoindre une pièce, pas en créer une) ;
        # les accessoires ne sont pas regroupés pour l'instant
        if reste and nette(ref) and fam != "accessoire":
            sim = np.array([float(u["e"] @ ref["e"]) - np.linalg.norm(u["c"] - ref["c"]) / 120 for u in reste])
            idx = [i for i in np.argsort(-sim) if sim[i] >= SIM_MIN and not (reste[i]["sids"] & ref["sids"])][:CANDIDATS]
            if idx:
                pris = set(ref["sids"])
                for u in memes(ref, [reste[i] for i in idx], fam):
                    if not (u["sids"] & pris): groupe.append(u); pris |= u["sids"]   # une pièce n'apparaît qu'une fois par séance
                reste = [u for u in reste if u not in groupe]
        groupes.append(fusion(groupe))
    return groupes

def fusion(unites):
    """Regroupe des unités en une seule, représentée par sa meilleure photo."""
    O = [o for u in unites for o in u["obs"]]; best = max(O, key=lambda o: o["q"])
    e = np.mean([o["e"] for o in O], 0)
    return {"id": "g:" + ",".join(sorted(o["id"] for o in O)), "obs": O, "sids": {o["sid"] for o in O}, "fam": best["fam"],
            "crop": best["crop"], "q": best["q"], "e": e / (np.linalg.norm(e) + 1e-9), "c": np.median([o["c"] for o in O], 0)}

familles = {}
for o in obs: familles.setdefault(o["fam"], []).append(fusion([{"obs": [o]}]))
print(len(obs), "photos de pièces à regrouper", flush=True)
for passage in (1, 2):      # 2e passage : on compare les pièces formées entre elles, pour rattraper les photos d'une même pièce restées séparées
    with ThreadPoolExecutor(6) as ex:
        res = dict(zip(familles, ex.map(lambda kv: regrouper(*kv), familles.items())))
    for fam in familles: print(f"  passage {passage} · {fam} : {len(familles[fam])} → {len(res[fam])} pièces", flush=True)
    familles = res

# 3e et 4e passages, inspirés du premier test « à l'œil » : une vue d'ensemble plutôt que des comparaisons locales.
def demander(cle, img, txt):
    """Appel au modèle d'arbitrage avec une planche ; réponses gardées dans le cache (une relance ne repaie pas)."""
    global _cli, n_planches
    if cle in CACHE: return CACHE[cle]
    if ESTIMER:
        with _verrou: n_planches += 1
        return ""
    import anthropic
    with _verrou:
        guard(0.001, "regroupement des pièces"); _cli = _cli or anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    b = io.BytesIO(); img.save(b, "JPEG", quality=82)
    for essai in range(3):
        try:
            m = _cli.messages.create(model=MODEL, max_tokens=2000, extra_body={"output_config": {"effort": "low"}}, messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": base64.b64encode(b.getvalue()).decode()}},
                {"type": "text", "text": txt}]}])
            break
        except Exception as e: err = e
    else:
        print("appel impossible :", str(err)[:120]); return ""
    t = "".join(x.text for x in m.content if x.type == "text")
    with _verrou:
        n_planches += 1; CACHE[cle] = t
        charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "regroupement (planche)")
        LOG.write(json.dumps({"cle": cle[:60], "reponse": t[:300]}, ensure_ascii=False) + "\n"); LOG.flush()
    return t

def grille(liste, cols, T=200):
    rows = (len(liste) + cols - 1) // cols
    im = Image.new("RGB", (cols * T, rows * T), "white"); d = ImageDraw.Draw(im)
    try: f = ImageFont.load_default(size=30)
    except Exception: f = ImageFont.load_default()
    for k, u in enumerate(liste):
        c = u["crop"].copy(); c.thumbnail((T - 6, T - 6)); X, Y = (k % cols) * T, (k // cols) * T
        im.paste(c, (X + 3, Y + 3)); d.rectangle([X, Y, X + 44, Y + 34], fill="white"); d.text((X + 4, Y + 1), str(k + 1), fill="red", font=f)
    return im

def lire(t, cle):
    try: return json.loads(t[t.find("{"): t.rfind("}") + 1]).get(cle)
    except Exception: return None

def sim(a, b): return float(a["e"] @ b["e"]) - np.linalg.norm(a["c"] - b["c"]) / 120

def catalogue(fam, groupes):
    """3e passage : le modèle voit les pièces de la famille par planches de 24 (ordonnées pour que les pièces proches
    soient sur la même planche, avec recouvrement) et désigne les doublons."""
    refs = [g for g in groupes if nette(g)]
    if fam == "accessoire" or len(refs) < 2: return groupes
    ordre, reste = [refs[0]], refs[1:]
    while reste:                                         # chaîne : chaque pièce suivie de sa plus proche voisine
        j = max(range(len(reste)), key=lambda i: sim(ordre[-1], reste[i])); ordre.append(reste.pop(j))
    parent = {id(g): g for g in groupes}
    def racine(g):
        while parent[id(g)] is not g: g = parent[id(g)]
        return g
    membres = {id(g): [g] for g in groupes}
    for debut in range(0, max(1, len(ordre) - 8), 16):
        lot = ordre[debut: debut + 24]
        if len(lot) < 2: break
        t = demander("T4|" + ",".join(g["id"] for g in lot), grille(lot, 6), prompt("textes/T4_catalogue.md", n=len(lot), famille=fam))
        for grp in lire(t, "doublons") or []:
            gs = [lot[n - 1] for n in grp if isinstance(n, int) and 1 <= n <= len(lot)]
            for g in gs[1:]:
                a, b = racine(gs[0]), racine(g)
                if a is b: continue
                sa = set().union(*[m["sids"] for m in membres[id(a)]]); sb = set().union(*[m["sids"] for m in membres[id(b)]])
                if sa & sb: continue                     # une pièce n'apparaît qu'une fois par séance
                parent[id(b)] = a; membres[id(a)] += membres.pop(id(b))
    return [fusion(ms) for ms in membres.values()]

def rattacher(fam, groupes):
    """4e passage : chaque photo partielle restée seule est comparée aux 8 pièces connues les plus proches."""
    if fam == "accessoire": return groupes
    cats = [g for g in groupes if nette(g)]; seuls = [g for g in groupes if not nette(g) and len(g["obs"]) == 1]
    def un(g):
        cand = sorted([c for c in cats if not (c["sids"] & g["sids"])], key=lambda c: -sim(g, c))[:8]
        if not cand: return g, None
        t = demander("T5|" + g["id"] + "|" + ",".join(c["id"] for c in cand), grille([g] + cand, 3),
                     prompt("textes/T5_rattachement.md", n=len(cand) + 1, famille=fam))
        n = lire(t, "piece")
        return g, (cand[n - 2] if isinstance(n, int) and 2 <= n <= len(cand) + 1 else None)
    with ThreadPoolExecutor(6) as ex: res = list(ex.map(un, seuls))
    ajouts = {}
    for g, c in res:
        if c is None: continue
        pris = set(c["sids"]).union(*[x["sids"] for x in ajouts.get(id(c), [])])
        if not (g["sids"] & pris): ajouts.setdefault(id(c), []).append(g)
    rattaches = {id(g) for gs in ajouts.values() for g in gs}
    return [fusion([g] + ajouts[id(g)]) if id(g) in ajouts else g for g in groupes if id(g) not in rattaches]

for nom, f in (("catalogue", catalogue), ("rattachement", rattacher)):
    with ThreadPoolExecutor(6) as ex:
        res = dict(zip(familles, ex.map(lambda kv: f(*kv), familles.items())))
    for fam in familles: print(f"  {nom} · {fam} : {len(familles[fam])} → {len(res[fam])} pièces", flush=True)
    familles = res
json.dump(CACHE, open(CACHE_F, "w"))
pieces = [{"fam": g["fam"], "obs": g["obs"]} for gs in familles.values() for g in gs]

if TEST:
    print(open(os.path.join(D, "regroupement_log.jsonl")).read()); raise SystemExit
if ESTIMER:
    print(n_planches, "planches Haiku au maximum, soit ≈", round(n_planches * 0.00035, 3), "$"); raise SystemExit

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
json.dump(out, open(os.path.join(D, "pieces.json"), "w"), ensure_ascii=False, indent=1)
print(len(obs), "observations →", len(out), "pièces |", sum(1 for p in out if p["ports"] >= CFG["ports_min_pour_generation"]),
      "portées au moins", CFG["ports_min_pour_generation"], "fois |", sum(p["generable"] for p in out), "avec des photos suffisantes |", n_planches, "planches Haiku")

"""Outils partagés : config, prompts, clés API (lues dans .env, jamais écrites par le code), plafond de dépense."""
import os, json, re
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = json.load(open(os.path.join(R, "config.json")))
# Essais : RUN=nom python3 algo/… travaille dans runs/nom/ (données, sorties, dépenses à part) avec runs/nom/config.json
# par-dessus config.json. La photothèque et les détections (data/galerie, data/detections.jsonl) restent communes.
RUN = os.environ.get("RUN")
BASE = os.path.join(R, "runs", RUN) if RUN else R
if RUN and os.path.exists(os.path.join(BASE, "config.json")):
    for k, v in json.load(open(os.path.join(BASE, "config.json"))).items():
        CFG[k] = {**CFG[k], **v} if isinstance(v, dict) and isinstance(CFG.get(k), dict) else v
D = os.path.join(BASE, "data"); O = os.path.join(BASE, "out")      # données et sorties de l'essai
os.makedirs(D, exist_ok=True)
LEDGER = os.path.join(D, "depenses.json")

# Tarifs en $ (vérifiés le 26 oct. 2026) : Haiku 5.5 par million de tokens (l'API Batch divise par 2) ;
# gpt-image-1-mini par image 1024x1024, plus les images d'entrée facturées en tokens.
# Ajout du 9 nov. 2026 : Sonnet 5.5 (tarifs Anthropic) ; gpt-image-2 (comparatif developersdigest.tech, non vérifié sur le site
# d'OpenAI) ; gpt-image-2.5-* facturés au token, prix inconnu : estimation prudente de 0,25 $ l'image.
TARIFS = {"claude-haiku-5-5": {"in": 0.10, "out": 0.50},
          "claude-sonnet-5-5": {"in": 2.0, "out": 10.0},
          "gpt-image-1-mini": {"low": 0.005, "medium": 0.011, "high": 0.036, "in_per_mtok": 2.5},
          "gpt-image-2": {"low": 0.006, "medium": 0.053, "high": 0.211, "in_per_mtok": 10.0},
          # constaté sur le tableau de bord OpenAI (9 nov. 2026) : 0,058 $ pour 4 images en qualité moyenne, entrées comprises ;
          # compté prudemment à 0,03 $ l'image
          "gpt-image-2.5-sunburst": {"low": 0.015, "medium": 0.03, "high": 0.1, "in_per_mtok": 0.0}}
def tarif_image(model, q):
    return TARIFS[model][q] if model in TARIFS else 0.25

GALERIE_INDEX = os.path.join(R, "data", "galerie.jsonl")

def galerie():
    """Index écrit par outils/lire_galerie.swift : {fichier: {"id": identifiant de la photo, "dt": date}}. Vide sinon."""
    if not os.path.exists(GALERIE_INDEX): return {}
    return {d["f"]: d for d in map(json.loads, open(GALERIE_INDEX))}

def photos_dir():
    """La photothèque lue par outils/lire_galerie.swift si elle existe, sinon le dossier de config.json."""
    if os.path.exists(GALERIE_INDEX): return os.path.join(R, "data", "galerie")
    p = CFG["dossier_photos"]
    return p if os.path.isabs(p) else os.path.normpath(os.path.join(R, p))

def env():
    p = os.path.join(R, ".env"); d = {}
    if os.path.exists(p):
        for l in open(p):
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.strip().split("=", 1); d[k.strip()] = v.strip().strip('"')
    d.update({k: v for k, v in os.environ.items() if k.endswith("_API_KEY")})
    return d

def prompt(path, **vars):
    t = open(os.path.join(R, "prompts", path), encoding="utf-8").read()
    t = re.sub(r"^---.*?---\s*", "", t, flags=re.S)          # retire l'en-tête
    for k, v in vars.items(): t = t.replace("{{" + k + "}}", str(v if v not in (None, "") else "aucun"))
    return t.strip()

def spent():
    return json.load(open(LEDGER))["total_usd"] if os.path.exists(LEDGER) else 0.0

def charge(usd, what):
    d = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"total_usd": 0.0, "lignes": []}
    d["total_usd"] = round(d["total_usd"] + usd, 5); d["lignes"].append([what, round(usd, 5)])
    json.dump(d, open(LEDGER, "w"), indent=1)

def guard(next_cost, what):
    if spent() + next_cost > CFG["budget_max_usd"]:
        raise SystemExit(f"Plafond atteint ({spent():.3f} $ dépensés, {CFG['budget_max_usd']} $ max) : arrêt avant « {what} ».")

# Accessoires de mode : seuls ceux-là entrent dans le dressing (pas les casques audio, serviettes, masques, déguisements…)
ACCESSOIRES_MODE = ("casquette", "bonnet", "chapeau", "bob", "écharpe", "echarpe", "foulard", "snood", "tour de cou", "gants",
                    "ceinture", "lunettes", "sac", "sacoche", "cabas", "pochette", "cravate", "nœud", "noeud", "collier", "chaîne",
                    "chaine", "bracelet", "montre", "bague", "boucle", "pendentif", "portefeuille", "bandoulière")
def est_mode(p):
    if (p.get("rayon") or "").lower() != "accessoire": return True
    t = (p.get("type") or "").lower()
    return any(k in t for k in ACCESSOIRES_MODE)

# Pull ou haut porté noué sur les épaules / autour du cou : la photo produit le dessinerait noué, comme une écharpe.
NOUE = re.compile(r"\bnou[ée]|drap[ée]|port[ée]e? sur les [ée]paules|autour (du cou|des [ée]paules)", re.I)
def porte_noue(p):
    if (p.get("rayon") or "").lower() == "accessoire": return False
    return bool(NOUE.search(" ".join(str(p.get(k) or "") for k in ("type", "coupe_col", "details_face"))))

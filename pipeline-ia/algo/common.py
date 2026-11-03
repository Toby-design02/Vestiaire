"""Outils partagés : config, prompts, clés API (lues dans .env, jamais écrites par le code), plafond de dépense."""
import os, json, re
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = json.load(open(os.path.join(R, "config.json")))
LEDGER = os.path.join(R, "data", "depenses.json")
os.makedirs(os.path.join(R, "data"), exist_ok=True)

# Tarifs en $ (vérifiés le 26 oct. 2026) : Haiku 5.5 par million de tokens (l'API Batch divise par 2) ;
# gpt-image-1-mini par image 1024x1024, plus les images d'entrée facturées en tokens.
TARIFS = {"claude-haiku-5-5": {"in": 0.10, "out": 0.50},
          "gpt-image-1-mini": {"low": 0.005, "medium": 0.011, "high": 0.036, "in_per_mtok": 2.5}}

def photos_dir():
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

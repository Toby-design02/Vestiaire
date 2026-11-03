"""Étape 4 : photo produit de chaque pièce avec l'API image d'OpenAI et le prompt P1.
Une seule fois par pièce (les images déjà faites sont sautées), seulement les pièces portées au moins N fois.
Usage : python3 algo/generation.py mini     (mini-test sur config.mini_test_pieces)
        python3 algo/generation.py tout"""
import os, sys, json, base64
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, prompt, charge, guard, TARIFS
from openai import OpenAI

PJ = os.path.join(R, "data", "pieces.json")
PIECES = json.load(open(PJ))
OUTD = os.path.join(R, "out", "produits"); os.makedirs(OUTD, exist_ok=True)
MODEL = CFG["modeles"]["image"]

def go(limit):
    cli = OpenAI(api_key=env()["OPENAI_API_KEY"])
    todo = [p for p in PIECES if p["ports"] >= CFG["ports_min_pour_generation"] and p["decoupes"] and not p["photo_produit"]]
    if limit: todo = todo[:limit]
    print(len(todo), "pièces à générer")
    for p in todo:
        q = CFG["image_qualite_si_logo"] if p.get("logos_textes") else CFG["image_qualite"]
        guard(TARIFS[MODEL][q] + 0.004, f"photo produit {p['id']}")       # + marge pour les images d'entrée
        desc = ", ".join(x for x in [p.get("type"), " / ".join(p.get("couleurs") or []), p.get("motif"), p.get("matiere"),
                                       p.get("coupe_col"), p.get("details_face")] if x)
        txt = prompt("images/P1_photo_produit.md", categorie=p.get("type") or p.get("rayon"), description=desc,
                     details_dos=p.get("details_dos"), logos_textes=p.get("logos_textes"))
        files = [open(os.path.join(R, d), "rb") for d in p["decoupes"]]
        try:
            r = cli.images.edit(model=MODEL, image=files, prompt=txt, size=CFG["image_taille"], quality=q, n=1)
        finally:
            for f in files: f.close()
        path = os.path.join(OUTD, p["id"] + ".png")
        open(path, "wb").write(base64.b64decode(r.data[0].b64_json))
        tin = getattr(getattr(r, "usage", None), "input_tokens", 0) or 0
        charge(TARIFS[MODEL][q] + tin * TARIFS[MODEL]["in_per_mtok"] / 1e6, f"photo produit {p['id']} ({q})")
        p["photo_produit"] = os.path.relpath(path, R)
        json.dump(PIECES, open(PJ, "w"), ensure_ascii=False, indent=1)       # sauvegarde après chaque image
        print("ok", p["id"], p.get("type"), q)

if __name__ == "__main__":
    go(CFG["mini_test_pieces"] if (sys.argv[1:] or ["mini"])[0] == "mini" else 0)

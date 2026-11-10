"""Essai : génère les mêmes pièces avec plusieurs modèles d'image, pour choisir à l'œil.
Usage : RUN=sonnet python3 algo/comparer_images.py
Prend les N meilleures pièces de l'essai (config : comparaison.pieces), les génère avec chaque couple
[modèle, qualité] de config : comparaison.modeles, et fait une planche out/comparaison/planche.jpg
(photos d'origine à gauche, puis un résultat par modèle). Plafond : budget_max_usd de l'essai."""
import os, sys, json, base64
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, prompt, charge, guard, TARIFS, D, O, tarif_image
from openai import OpenAI
from PIL import Image, ImageDraw

C = CFG["comparaison"]
PIECES = json.load(open(os.path.join(D, "pieces.json")))
OUTD = os.path.join(O, "comparaison"); os.makedirs(OUTD, exist_ok=True)
choix = [p for p in sorted(PIECES, key=lambda p: (-p["ports"], -len(p["decoupes"])))
         if p.get("generable") and p["decoupes"] and p["rayon"] != "accessoire"][:C["pieces"]]
cli = OpenAI(api_key=env()["OPENAI_API_KEY"])
print(len(choix), "pièces ×", len(C["modeles"]), "modèles")
for p in choix:
    desc = ", ".join(x for x in [p.get("type"), " / ".join(p.get("couleurs") or []), p.get("motif"), p.get("matiere"),
                                   p.get("coupe_col"), p.get("details_face")] if x)
    txt = prompt("images/P1_photo_produit.md", categorie=p.get("type") or p.get("rayon"), description=desc,
                 details_dos=p.get("details_dos"), logos_textes=p.get("logos_textes"))
    for model, q in C["modeles"]:
        path = os.path.join(OUTD, f"{p['id']}__{model}__{q}.png")
        if os.path.exists(path): continue
        guard(tarif_image(model, q) + 0.01, f"{p['id']} {model} {q}")
        files = [open(os.path.join(R, d), "rb") for d in p["decoupes"]]
        try:
            r = cli.images.edit(model=model, image=files, prompt=txt, size=CFG["image_taille"], quality=q, n=1)
            open(path, "wb").write(base64.b64decode(r.data[0].b64_json))
            u = getattr(r, "usage", None)
            charge(tarif_image(model, q) + (getattr(u, "input_tokens", 0) or 0) * TARIFS.get(model, {}).get("in_per_mtok", 10) / 1e6,
                   f"comparaison {p['id']} {model} {q}")
            print("ok", p["id"], p.get("type"), model, q, flush=True)
        except Exception as e:
            print("échec", model, q, ":", str(e)[:160], flush=True)
        finally:
            for f in files: f.close()

# planche : une ligne par pièce
S = 300; cols = 3 + len(C["modeles"])
im = Image.new("RGB", (cols * S, len(choix) * (S + 20) + 20), "white"); d = ImageDraw.Draw(im)
for j, (model, q) in enumerate(C["modeles"]): d.text((3 * S + j * S + 4, 4), f"{model} {q}", fill="black")
for i, p in enumerate(choix):
    Y = 20 + i * (S + 20); d.text((4, Y + 2), f"{p['id']} {p.get('type')}"[:60], fill="black")
    for k, f in enumerate(p["decoupes"][:3]):
        c = Image.open(os.path.join(R, f)).convert("RGB"); c.thumbnail((S - 6, S - 6)); im.paste(c, (k * S, Y + 18))
    for j, (model, q) in enumerate(C["modeles"]):
        f = os.path.join(OUTD, f"{p['id']}__{model}__{q}.png")
        if os.path.exists(f):
            c = Image.open(f).convert("RGB"); c.thumbnail((S - 6, S - 6)); im.paste(c, ((3 + j) * S, Y + 18))
im.save(os.path.join(OUTD, "planche.jpg"), quality=85)
print("planche :", os.path.relpath(os.path.join(OUTD, "planche.jpg"), R))

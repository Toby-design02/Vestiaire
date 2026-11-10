"""Étape 4 : photo produit de chaque pièce avec l'API image d'OpenAI et le prompt P1.
Une seule fois par pièce (les images déjà faites sont sautées), seulement les pièces portées au moins N fois.
Usage : python3 algo/generation.py mini     (mini-test sur config.mini_test_pieces)
        python3 algo/generation.py tout"""
import os, sys, json, base64
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, prompt, charge, guard, TARIFS, D, O, tarif_image
from openai import OpenAI

PJ = os.path.join(D, "pieces.json")
PIECES = json.load(open(PJ))
OUTD = os.path.join(O, "produits"); os.makedirs(OUTD, exist_ok=True)
MODEL = CFG["modeles"]["image"]

from PIL import Image
def assez_visible(p):
    """Au moins une découpe assez grande : sinon le modèle invente la pièce (ex. un t-shirt vu seulement au col)."""
    for f in p.get("decoupes") or []:
        try:
            w, h = Image.open(os.path.join(R, f)).size
            if min(w, h) >= 160 and w * h >= 60000: return True
        except Exception: pass
    return False

def verifier(p, desc, cli_a):
    """Haiku regarde les photos qui seront envoyées : suffisent-elles pour une photo produit fidèle ? (≈ 0,0004 $)"""
    contenu = []
    for d in p["decoupes"]:
        contenu.append({"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                                    "data": base64.b64encode(open(os.path.join(R, d), "rb").read()).decode()}})
    contenu.append({"type": "text", "text": prompt("textes/T3_verification.md", description=desc)})
    m = cli_a.messages.create(model=CFG["modeles"]["arbitrage"], max_tokens=1500, extra_body={"output_config": {"effort": "low"}},
                              messages=[{"role": "user", "content": contenu}])
    M = CFG["modeles"]["arbitrage"]
    charge((m.usage.input_tokens * TARIFS[M]["in"] + m.usage.output_tokens * TARIFS[M]["out"]) / 1e6, f"vérification {p['id']}")
    t = "".join(x.text for x in m.content if x.type == "text")
    try: r = json.loads(t[t.find("{"): t.rfind("}") + 1])
    except Exception: return False, "réponse illisible"
    return r.get("suffisant") is True, r.get("manque")

def go(limit):
    if "--reverifier" in sys.argv:          # après un changement du prompt T3 : on redonne leur chance aux pièces écartées
        for p in PIECES:
            if (p.get("photos_insuffisantes") or "").startswith("vérification"):
                p["generable"], p["photos_insuffisantes"], p["verifie"] = True, None, False
    import anthropic
    cli_a = anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    cli = OpenAI(api_key=env()["OPENAI_API_KEY"])
    todo = [p for p in PIECES if p["ports"] >= CFG["ports_min_pour_generation"] and p["decoupes"] and not p["photo_produit"] and p.get("generable") and assez_visible(p)]
    if limit:   # mini-test : complète avec des pièces vues une seule fois, pour juger la qualité tout de suite
        todo += [p for p in PIECES if p not in todo and p["decoupes"] and not p["photo_produit"] and p["rayon"] != "accessoire" and p.get("generable") and assez_visible(p)]
        todo = todo[:limit]
    print(len(todo), "pièces à générer")
    for p in todo:
        q = CFG["image_qualite_si_logo"] if p.get("logos_textes") else CFG["image_qualite"]
        guard(tarif_image(MODEL, q) + 0.004, f"photo produit {p['id']}")       # + marge pour les images d'entrée
        desc = ", ".join(x for x in [p.get("type"), " / ".join(p.get("couleurs") or []), p.get("motif"), p.get("matiere"),
                                       p.get("coupe_col"), p.get("details_face")] if x)
        if not p.get("verifie"):
            ok, manque = verifier(p, desc, cli_a)
            if not ok:
                p["generable"] = False; p["photos_insuffisantes"] = f"vérification : {manque or 'photos insuffisantes'}"
                json.dump(PIECES, open(PJ, "w"), ensure_ascii=False, indent=1); print("écartée", p["id"], p.get("type"), "→", manque); continue
            p["verifie"] = True
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
        charge(tarif_image(MODEL, q) + tin * TARIFS.get(MODEL, {}).get("in_per_mtok", 10) / 1e6, f"photo produit {p['id']} ({q})")
        p["photo_produit"] = os.path.relpath(path, R)
        json.dump(PIECES, open(PJ, "w"), ensure_ascii=False, indent=1)       # sauvegarde après chaque image
        print("ok", p["id"], p.get("type"), q)

if __name__ == "__main__":
    go(CFG["mini_test_pieces"] if (sys.argv[1:] or ["mini"])[0] == "mini" else 0)

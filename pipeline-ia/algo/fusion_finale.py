"""Étape 4 bis : dernier passage sur les pièces qui ont une photo produit. Les photos produit, nettes et de face,
rendent les doublons faciles à voir (ex. le même blouson compté trois fois). Haiku voit des planches de 16 pièces
(photo produit + vraie photo) et désigne les doublons ; les doublons sont fusionnés dans la pièce la plus portée,
et leurs photos produit deviennent des variantes : l'utilisateur choisit la meilleure (dans l'app, ou data/choix_photos.json).
Usage : python3 algo/fusion_finale.py     (≈ 0,01 $)"""
import os, sys, io, json, base64
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, prompt, charge, guard, TARIFS, D, est_mode
import numpy as np, cv2, anthropic
from PIL import Image, ImageDraw, ImageFont

PJ = os.path.join(D, "pieces.json"); PIECES = json.load(open(PJ))
MODEL = CFG["modeles"].get("fusion", CFG["modeles"]["arbitrage"])   # Sonnet : peu de planches, décision importante
FAMILLE = {"veste": "vestes et pulls", "pull": "vestes et pulls", "haut": "hauts", "bas": "bas", "chaussures": "chaussures",
           "accessoire": "accessoires"}
net = cv2.dnn.readNet(os.path.join(R, "models", "image_classification_mobilenetv2_2022apr.onnx"))
def empreinte(im):
    a = (np.array(im.convert("RGB").resize((224, 224))).astype(np.float32) / 255 - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    net.setInput(a.transpose(2, 0, 1)[None].astype(np.float32)); v = net.forward().flatten(); return v / (np.linalg.norm(v) + 1e-9)

def case(p, T=120):
    im = Image.new("RGB", (2 * T, T + 30), "white")
    a = Image.open(os.path.join(R, p["photo_produit"])).convert("RGB"); a.thumbnail((T - 4, T - 4)); im.paste(a, (2, 28))
    b = Image.open(os.path.join(R, p["decoupes"][0])).convert("RGB"); b.thumbnail((T - 4, T - 4)); im.paste(b, (T + 2, 28))
    return im

def planche(lot):
    W, H = 240, 150; im = Image.new("RGB", (4 * W, ((len(lot) + 3) // 4) * H), (235, 235, 235)); d = ImageDraw.Draw(im)
    try: f = ImageFont.load_default(size=26)
    except Exception: f = ImageFont.load_default()
    for k, p in enumerate(lot):
        X, Y = (k % 4) * W, (k // 4) * H; im.paste(case(p), (X, Y)); d.text((X + 4, Y), str(k + 1), fill="red", font=f)
    b = io.BytesIO(); im.save(b, "JPEG", quality=85); return base64.b64encode(b.getvalue()).decode()

cli = anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
def doublons(lot, fam):
    guard(0.002, "fusion finale")
    m = cli.messages.create(model=MODEL, max_tokens=2000, extra_body={"output_config": {"effort": "low"}}, messages=[{"role": "user", "content": [
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": planche(lot)}},
        {"type": "text", "text": prompt("textes/T6_doublons_finaux.md", n=len(lot), famille=fam)}]}])
    charge((m.usage.input_tokens * TARIFS[MODEL]["in"] + m.usage.output_tokens * TARIFS[MODEL]["out"]) / 1e6, "fusion finale (planche)")
    t = "".join(x.text for x in m.content if x.type == "text")
    try: return json.loads(t[t.find("{"): t.rfind("}") + 1]).get("doublons") or []
    except Exception: return []

actives = [p for p in PIECES if p.get("photo_produit") and p.get("statut") != "fusionnee" and est_mode(p)
           and os.path.exists(os.path.join(R, p["photo_produit"])) and p.get("decoupes")]
for p in actives: p["_e"] = empreinte(Image.open(os.path.join(R, p["photo_produit"])))
avant, n_fus = len(actives), 0
for fam in dict.fromkeys(FAMILLE.values()):
    ps = [p for p in actives if FAMILLE.get(p["rayon"]) == fam]
    if len(ps) < 2: continue
    ordre, reste = [ps[0]], ps[1:]
    while reste:                                         # pièces proches côte à côte
        j = max(range(len(reste)), key=lambda i: float(reste[i]["_e"] @ ordre[-1]["_e"])); ordre.append(reste.pop(j))
    for debut in range(0, max(1, len(ordre) - 4), 12):   # planches de 16, recouvrement de 4
        lot = [p for p in ordre[debut: debut + 16] if p.get("statut") != "fusionnee"]
        if len(lot) < 2: continue
        for grp in doublons(lot, fam):
            gs = [lot[n - 1] for n in grp if isinstance(n, int) and 1 <= n <= len(lot)]
            gs = [g for g in gs if g.get("statut") != "fusionnee"]
            if len(gs) < 2: continue
            main = max(gs, key=lambda g: g["ports"])
            for g in gs:
                if g is main: continue
                if set(g["seances"]) & set(main["seances"]):                       # jamais deux fois dans la même tenue
                    print("  pas de fusion", g["id"], "→", main["id"], ": portées dans la même tenue"); continue
                main["seances"] = sorted(set(main["seances"]) | set(g["seances"])); main["ports"] = len(main["seances"])
                main["nb_photos"] = main.get("nb_photos", 0) + g.get("nb_photos", 0)
                main["premiere_fois"] = min(main["premiere_fois"], g["premiere_fois"]); main["derniere_fois"] = max(main["derniere_fois"], g["derniere_fois"])
                g["statut"], g["fusionnee_dans"] = "fusionnee", main["id"]; n_fus += 1
                # la photo produit du doublon n'est pas jetée : elle devient une variante, au choix de l'utilisateur
                main["photos_alternatives"] = main.get("photos_alternatives", []) + [g["photo_produit"]] + g.get("photos_alternatives", [])
                print("fusion", g["id"], g.get("type"), "→", main["id"], main.get("type"), flush=True)
# fusions décidées par l'utilisateur : data/fusions_manuelles.json = [["p000", "p002", "p008"], …] (la plus portée garde la fiche)
FM = os.path.join(D, "fusions_manuelles.json")
par_id = {p["id"]: p for p in PIECES}
for grp in (json.load(open(FM)) if os.path.exists(FM) else []):
    gs = [par_id[i] for i in grp if i in par_id]
    while any(g.get("statut") == "fusionnee" for g in gs):                 # suit les fusions déjà faites
        gs = [par_id[g["fusionnee_dans"]] if g.get("statut") == "fusionnee" else g for g in gs]
    gs = list({g["id"]: g for g in gs}.values())
    if len(gs) < 2: continue
    main = max(gs, key=lambda g: g["ports"])
    for g in gs:
        if g is main: continue
        main["seances"] = sorted(set(main["seances"]) | set(g["seances"])); main["ports"] = len(main["seances"])
        main["premiere_fois"] = min(main["premiere_fois"], g["premiere_fois"]); main["derniere_fois"] = max(main["derniere_fois"], g["derniere_fois"])
        if g.get("photo_produit"): main["photos_alternatives"] = main.get("photos_alternatives", []) + [g["photo_produit"]] + g.get("photos_alternatives", [])
        g["statut"], g["fusionnee_dans"] = "fusionnee", main["id"]; n_fus += 1
        print("fusion manuelle", g["id"], "→", main["id"], flush=True)
for p in PIECES: p.pop("_e", None)
json.dump(PIECES, open(PJ, "w"), ensure_ascii=False, indent=1)
print(avant, "pièces avec photo produit →", avant - n_fus, "après fusion des doublons")

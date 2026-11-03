"""Étape 1a (locale, gratuite) : pour chaque photo, date EXIF, personnes, visages et empreintes faciales.
Résultat incrémental dans data/detections.jsonl : on peut couper et relancer, les photos déjà faites sont sautées.
Usage : python3 algo/detect.py [nombre_max]   (WORKERS=4 pour régler le parallélisme)"""
import os, sys, json, numpy as np, cv2
from multiprocessing import Pool
from PIL import Image, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, photos_dir

PH = photos_dir()
OUT = os.path.join(R, "data", "detections.jsonl")
M = os.path.join(R, "models")
_m = {}

def models():
    if not _m:
        _m["det"] = cv2.dnn.readNet(os.path.join(M, "object_detection_yolox_2022nov.onnx"))
        _m["face"] = cv2.FaceDetectorYN.create(os.path.join(M, "face_detection_yunet_2023mar.onnx"), "", (320, 320), 0.7)
        _m["rec"] = cv2.FaceRecognizerSF.create(os.path.join(M, "face_recognition_sface_2021dec.onnx"), "")
        g, s = [], []
        for st in (8, 16, 32):
            n = 640 // st; xv, yv = np.meshgrid(np.arange(n), np.arange(n))
            g.append(np.stack((xv, yv), 2).reshape(1, -1, 2)); s.append(np.full((1, n * n, 1), st))
        _m["grid"], _m["strides"] = np.concatenate(g, 1), np.concatenate(s, 1)
    return _m

def persons(img):
    """Détecteur YOLOX (classe 0 = personne). Boîtes renvoyées en fractions de l'image + score."""
    m = models(); h, w = img.shape[:2]; r = min(640 / h, 640 / w)
    pad = np.full((640, 640, 3), 114, np.uint8)
    pad[:int(h * r), :int(w * r)] = cv2.resize(img, (int(w * r), int(h * r)))
    blob = np.transpose(cv2.cvtColor(pad, cv2.COLOR_BGR2RGB).astype(np.float32), (2, 0, 1))[None]
    m["det"].setInput(blob); d = m["det"].forward(m["det"].getUnconnectedOutLayersNames())[0][0]
    d[:, :2] = (d[:, :2] + m["grid"][0]) * m["strides"][0]; d[:, 2:4] = np.exp(d[:, 2:4]) * m["strides"][0]
    sc = d[:, 4] * d[:, 5]
    b = np.stack([d[:, 0] - d[:, 2] / 2, d[:, 1] - d[:, 3] / 2, d[:, 2], d[:, 3]], 1)
    keep = cv2.dnn.NMSBoxes(b.tolist(), sc.tolist(), 0.4, 0.5)
    out = []
    for k in np.array(keep).flatten():
        x, y, bw, bh = b[k] / r
        x0, y0, x1, y1 = max(0, x), max(0, y), min(w, x + bw), min(h, y + bh)
        out.append([round(float(x0 / w), 4), round(float(y0 / h), 4), round(float(x1 / w), 4), round(float(y1 / h), 4), round(float(sc[k]), 3)])
    return out

def faces(img):
    """YuNet (détection) + SFace (empreinte). « eye » = écart des yeux / largeur du visage : petit = profil."""
    m = models(); h, w = img.shape[:2]
    m["face"].setInputSize((w, h)); _, f = m["face"].detect(img)
    out = []
    for row in (f if f is not None else []):
        emb = m["rec"].feature(m["rec"].alignCrop(img, row)).flatten()
        x, y, fw, fh = row[:4]
        out.append({"b": [round(float(x / w), 4), round(float(y / h), 4), round(float((x + fw) / w), 4), round(float((y + fh) / h), 4)],
                    "s": round(float(row[14]), 3), "eye": round(float(abs(row[4] - row[6]) / max(fw, 1)), 3),
                    "emb": [round(float(v), 4) for v in emb]})
    return out

def one(f):
    try:
        im = Image.open(os.path.join(PH, f)); ex = im.getexif(); sub = ex.get_ifd(0x8769)
        dt = sub.get(36867) or ex.get(306); make = ex.get(271); make = str(make) if make else None
        if not dt or str(dt)[:4] < CFG["date_min"][:4]: return {"f": f, "dt": str(dt) if dt else None, "skip": "date"}
        im = ImageOps.exif_transpose(im).convert("RGB"); im.thumbnail((1280, 1280))
        img = cv2.cvtColor(np.array(im), cv2.COLOR_RGB2BGR)
        sharp = float(cv2.Laplacian(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), cv2.CV_64F).var())
        return {"f": f, "dt": str(dt), "make": make, "wh": [im.width, im.height], "sharp": round(sharp, 1),
                "persons": persons(img), "faces": faces(img)}
    except Exception as e:
        return {"f": f, "err": str(e)[:200]}

if __name__ == "__main__":
    done = set()
    if os.path.exists(OUT):
        for l in open(OUT):
            try: done.add(json.loads(l)["f"])
            except Exception: pass
    todo = sorted(f for f in os.listdir(PH) if f.lower().endswith((".jpg", ".jpeg")) and f not in done)
    if len(sys.argv) > 1: todo = todo[:int(sys.argv[1])]
    print("à traiter", len(todo), "| déjà faites", len(done), flush=True)
    with open(OUT, "a") as fo, Pool(int(os.environ.get("WORKERS", 3))) as pool:
        for i, r in enumerate(pool.imap_unordered(one, todo, chunksize=4)):
            fo.write(json.dumps(r) + "\n"); fo.flush()
            if i % 100 == 0: print(i, flush=True)
    print("fini", flush=True)

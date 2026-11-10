"""Étape 2 (Claude Haiku, API Batch = moitié prix) : chaque séance → fiche JSON de chaque pièce portée.
Usage :  python3 algo/lecture.py soumettre [N]   (N premières séances, pour un test)
         python3 algo/lecture.py recuperer"""
import os, sys, json, base64, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import R, CFG, env, prompt, charge, guard, TARIFS, D, O
import anthropic

SESS = json.load(open(os.path.join(D, "sessions.json")))
STATE = os.path.join(D, "lecture_batch.json")
MODEL = CFG["modeles"]["lecture"]

def request(s):
    content = []
    for i, v in enumerate(s["vues"]):
        b64 = base64.b64encode(open(os.path.join(R, v["recadrage"]), "rb").read()).decode()
        content.append({"type": "text", "text": f"Photo {i} ({v['angle']})"})
        content.append({"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64}})
    content.append({"type": "text", "text": prompt("textes/T1_lecture_tenue.md", angles=", ".join(v["angle"] for v in s["vues"]))})
    return {"custom_id": s["id"], "params": {"model": MODEL, "max_tokens": 4000, "output_config": {"effort": "low"}, "messages": [{"role": "user", "content": content}]}}

def lire_json(txt):
    """Extrait {"pieces": [...]} de la réponse ; si elle est coupée, garde les pièces complètes."""
    t = txt.replace("```json", "").replace("```", "")
    t = t[t.find("{"):]
    try: return json.loads(t[: t.rfind("}") + 1])["pieces"]
    except Exception: pass
    for fin in range(len(t), 0, -1):                     # réponse coupée : on ferme après la dernière pièce complète
        if t[fin - 1] == "}":
            try: return json.loads(t[:fin] + "]}")["pieces"]
            except Exception: continue
    raise ValueError("JSON illisible")

def soumettre(n):
    todo = SESS[:n] if n else SESS
    est = len(todo) * ((CFG["recadrage_cote_long_px"] / 768) ** 2 * 4500 * TARIFS[MODEL]["in"] + 1200 * TARIFS[MODEL]["out"]) / 1e6 / 2
    guard(est, f"lecture de {len(todo)} séances (≈ {est:.3f} $)")
    c = anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    b = c.messages.batches.create(requests=[request(s) for s in todo])
    json.dump({"batch_id": b.id, "n": len(todo)}, open(STATE, "w"))
    print("batch envoyé", b.id, len(todo), "séances, coût estimé ≈", round(est, 3), "$")

def recuperer():
    st = json.load(open(STATE)); c = anthropic.Anthropic(api_key=env()["ANTHROPIC_API_KEY"])
    while True:
        b = c.messages.batches.retrieve(st["batch_id"])
        if b.processing_status == "ended": break
        print("en cours…", b.request_counts); time.sleep(30)
    out, tin, tout = {}, 0, 0
    for res in c.messages.batches.results(st["batch_id"]):
        if res.result.type != "succeeded": out[res.custom_id] = {"erreur": res.result.type}; continue
        m = res.result.message; tin += m.usage.input_tokens; tout += m.usage.output_tokens
        txt = "".join(x.text for x in m.content if x.type == "text")
        try: out[res.custom_id] = lire_json(txt)
        except Exception: out[res.custom_id] = {"erreur": f"{m.stop_reason} | blocs {[x.type for x in m.content]} | {txt[:200]}"}
    cost = (tin * TARIFS[MODEL]["in"] + tout * TARIFS[MODEL]["out"]) / 1e6 / 2
    if not st.get("facture"):                            # relancer recuperer ne compte pas deux fois la dépense
        charge(cost, f"lecture Haiku batch ({tin} tokens in, {tout} out)"); st["facture"] = True; json.dump(st, open(STATE, "w"))
    json.dump(out, open(os.path.join(D, "lecture.json"), "w"), ensure_ascii=False, indent=1)
    err = [k for k, v in out.items() if isinstance(v, dict)]
    print(len(out), "séances lues,", len(err), "illisibles, coût réel", round(cost, 4), "$")
    for k in err[:5]: print("  ", k, out[k]["erreur"][:160])

if __name__ == "__main__":
    if sys.argv[1] == "soumettre": soumettre(int(sys.argv[2]) if len(sys.argv) > 2 else 0)
    else: recuperer()

"""Generate illustration frames with the Gemini image API (key injected by the environment's network secret).

usage: python3 gen_images.py frames.json out_dir [--model gemini-3.1-flash-image] [--workers 4] [--only id,id]
frames.json = [{"id": "f001", "prompt": "...", "apex": true}]  (apex=true attaches the Apex reference sheet)
Existing out_dir/<id>.png files are skipped, so the script can be re-run after a failure.
"""
import base64, json, subprocess, sys, time, argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

STYLE = ("Clean hand-drawn explainer illustration in a simple cartoon style: thin, even black ink outlines; "
         "stick-figure characters with plain white perfectly round heads, small black dot eyes, simple eyebrows and mouth, "
         "thin black stick-line arms and legs, simple period clothing drawn over the stick body; flat colours with soft, subtle shading; "
         "a simple, uncluttered background that clearly shows the setting; wide 16:9 composition with the subject centred and plenty of breathing room. "
         "Vehicles are simplified, accurate period shapes with no logos, no sponsor names and no race numbers. "
         "Absolutely no text, letters, numbers, captions, logos, watermarks or signatures anywhere in the image.")
APEX = ("Apex, the recurring host: a stick figure with a plain white round head, vintage brown leather racing goggles pushed up on his forehead "
        "(always), orange gloves (always), and an off-white top with one vertical orange stripe unless a period costume is described.")

ap = argparse.ArgumentParser()
ap.add_argument("frames"); ap.add_argument("out")
ap.add_argument("--model", default="gemini-3.1-flash-image")
ap.add_argument("--workers", type=int, default=4)
ap.add_argument("--only", default="")
ap.add_argument("--ref", default=str(Path(__file__).resolve().parent.parent / "gen" / "apex_ref.png"))
a = ap.parse_args()
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
frames = json.loads(Path(a.frames).read_text())
if a.only: frames = [f for f in frames if f["id"] in a.only.split(",")]
ref_b64 = base64.b64encode(Path(a.ref).read_bytes()).decode() if Path(a.ref).exists() else None
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{a.model}:generateContent"


def call(body):
    p = subprocess.run(["curl", "-sS", "--max-time", "180", "-H", "Content-Type: application/json", "-d", "@-", URL],
                       input=json.dumps(body).encode(), capture_output=True)
    return json.loads(p.stdout or b"{}")


def gen(f):
    dst = out / f"{f['id']}.png"
    if dst.exists(): return f["id"], "skip"
    parts = []
    if f.get("apex") and ref_b64:
        parts.append({"inline_data": {"mime_type": "image/png", "data": ref_b64}})
        parts.append({"text": "The attached image is the character reference sheet for Apex: keep his design exactly (white round head, goggles on the forehead, orange gloves)."})
    parts.append({"text": f"{STYLE}\n{APEX if f.get('apex') else ''}\nScene: {f['prompt']}"})
    body = {"contents": [{"parts": parts}], "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "16:9"}}}
    for attempt in range(6):
        r = call(body)
        for c in r.get("candidates", []):
            for pt in c.get("content", {}).get("parts", []):
                d = pt.get("inline_data") or pt.get("inlineData")
                if d: dst.write_bytes(base64.b64decode(d["data"])); return f["id"], "ok"
        err = r.get("error", {}); code = err.get("code")
        if code in (429, 500, 503) or not err: time.sleep(10 * (attempt + 1)); continue
        return f["id"], f"error {code}: {err.get('message', '')[:120]}"
    return f["id"], "gave up"


with ThreadPoolExecutor(a.workers) as ex:
    for fid, st in ex.map(gen, frames):
        print(fid, st, flush=True)

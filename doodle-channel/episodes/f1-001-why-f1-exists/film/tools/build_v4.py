"""v4 editor: illustrated stills cut on every spoken phrase (reference-explainer style).

1. times every frame from the voice (timeline2.json paragraph starts + Whisper word times)
2. composes each frame to 1920x1080: AI image (gen/images/<id>.png) + handwritten label / red X, or a text card
   (a missing AI image becomes a grey placeholder showing its prompt, so the cut can be checked before generation)
3. renders each still with a slow 3 % push-in, concatenates, writes events_v4.json for the sound mix
usage: python3 build_v4.py [--placeholders-ok]
"""
import json, re, subprocess, sys, textwrap
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent.parent
W, H, FPS = 1920, 1080, 30
INK, PAPER, RED, ORANGE = (26, 26, 26), (255, 255, 255), (220, 40, 40), (242, 107, 33)
HAND = str(HERE / "fonts/PatrickHand.ttf")
frames = json.loads((HERE / "frames_v4.json").read_text())
T = json.loads((HERE / "timeline2.json").read_text())
words = json.loads((HERE / "voice2/words.json").read_text())
dur = json.loads((HERE / "voice2/dur.json").read_text())
lines = {x["id"]: x["text"] for x in json.loads((HERE / "voice2/lines.json").read_text())}
para_t0 = {p["id"]: p["t0"] for p in T["paras"]}
IMG, OUT = HERE / "gen/images", HERE / "out/v4"
(OUT / "stills").mkdir(parents=True, exist_ok=True); (OUT / "segs").mkdir(exist_ok=True)


# ---------- timing ----------
def snap(ws, i):
    lo, hi = max(1, i - 3), min(len(ws) - 1, i + 3)
    if lo > hi: return max(0, min(i, len(ws) - 1))
    return max(range(lo, hi + 1), key=lambda j: (ws[j][1] - ws[j - 1][2]) - abs(j - i) * .02)

chunk_t = {}
by_para = {}
for f in frames: by_para.setdefault(f["para"], {}).setdefault(f["chunk"], f["text"])
for pid, chs in by_para.items():
    ws, d, p0 = words.get(pid, []), dur[pid], para_t0[pid]
    order = sorted(chs); total = sum(len(chs[c].split()) for c in order); acc = 0
    for k, c in enumerate(order):
        if k == 0 or not ws: s = 0.0 if k == 0 else acc / total * d
        else: j = snap(ws, round(acc / total * len(ws))); s = max(0.0, ws[j][1] - .1)
        chunk_t[c] = p0 + s; acc += len(chs[c].split())

starts = []
for f in frames:
    c0 = chunk_t[f["chunk"]]
    nxt = next((chunk_t[g["chunk"]] for g in frames if g["chunk"] > f["chunk"]), None)
    c1 = nxt if nxt is not None else T["dur"]
    starts.append(c0 + (c1 - c0) * f["part"] / f["parts"])
title = T["title"]
seq = []   # (id, t0, t1, frame-or-title)
for i, f in enumerate(frames):
    t0 = 0.0 if i == 0 else starts[i]
    t1 = starts[i + 1] if i + 1 < len(frames) else T["dur"]
    if title and t0 < title["t0"] < t1:          # the title card cuts in between P02 and P03
        seq.append((f["id"], t0, title["t0"], f)); seq.append(("title", title["t0"], title["t1"], None))
        if t1 > title["t1"]: seq.append((f["id"] + "_", title["t1"], t1, f))
        continue
    if title and title["t0"] <= t0 < title["t1"]: t0 = title["t1"]
    seq.append((f["id"], t0, t1, f))


# ---------- composition ----------
def font(size): return ImageFont.truetype(HAND, size)
def fit_cover(im):
    r = max(W / im.width, H / im.height); im = im.resize((round(im.width * r), round(im.height * r)), Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2; return im.crop((x, y, x + W, y + H))
def label(dr, text):
    f = font(64); tw = dr.textlength(text, font=f); x, y = 70, 56
    dr.rounded_rectangle([x - 26, y - 14, x + tw + 26, y + 84], 18, fill=PAPER, outline=INK, width=5)
    dr.text((x, y), text, font=f, fill=INK)
def red_x(dr):
    for a, b in (((W * .2, H * .12), (W * .8, H * .9)), ((W * .8, H * .12), (W * .2, H * .9))): dr.line([a, b], fill=RED, width=28)
def icon(dr, kind, cx, cy):
    if kind == "question": dr.text((cx, cy), "?", font=font(150), fill=INK, anchor="mm")
    elif kind == "clock": dr.ellipse([cx - 60, cy - 60, cx + 60, cy + 60], outline=INK, width=8); dr.line([(cx, cy), (cx, cy - 40)], fill=INK, width=8); dr.line([(cx, cy), (cx + 30, cy + 10)], fill=INK, width=8)
    elif kind == "flag":
        for r in range(3):
            for c in range(4): dr.rectangle([cx - 80 + c * 40, cy - 60 + r * 40, cx - 40 + c * 40, cy - 20 + r * 40], fill=INK if (r + c) % 2 else PAPER, outline=INK, width=3)
def card(text, sub=None, ico=None):
    im = Image.new("RGB", (W, H), PAPER); dr = ImageDraw.Draw(im)
    size = 150 if len(text) <= 14 else 120 if len(text) <= 22 else 96
    dr.text((W / 2, H / 2 - (40 if sub else 0)), text, font=font(size), fill=INK, anchor="mm")
    if sub: dr.text((W / 2, H / 2 + size * .75), sub, font=font(64), fill=(110, 110, 110), anchor="mm")
    if ico: icon(dr, ico, W - 230, 200)
    return im
def placeholder(f):
    im = Image.new("RGB", (W, H), (226, 226, 226)); dr = ImageDraw.Draw(im)
    dr.text((W / 2, 120), f"[AI image pending: {f['id']}]", font=font(56), fill=(120, 120, 120), anchor="mm")
    for k, ln in enumerate(textwrap.wrap(f["prompt"], 70)[:9]): dr.text((120, 240 + k * 70), ln, font=font(48), fill=INK)
    return im

missing = []
for sid, t0, t1, f in seq:
    dst = OUT / "stills" / f"{sid}.png"
    if sid == "title": im = card("HOW A NEWSPAPER STUNT", sub="became Formula 1", ico="flag")
    elif f["kind"] == "card": im = card(f["text"].upper() if False else f["text"], f.get("sub"), f.get("icon"))
    else:
        src = IMG / f"{f['id']}.png"
        if src.exists(): im = fit_cover(Image.open(src).convert("RGB"))
        else: im = placeholder(f); missing.append(f["id"])
        dr = ImageDraw.Draw(im)
        if f.get("x"): red_x(dr)
        if f.get("label"): label(dr, f["label"])
    im.save(dst)
if missing and "--placeholders-ok" not in sys.argv:
    sys.exit(f"{len(set(missing))} AI images missing (run gen_images.py, or pass --placeholders-ok)")

# ---------- segments with a slow push-in, then concat ----------
lst = []
for sid, t0, t1, f in seq:
    n = max(2, round((t1 - t0) * FPS)); seg = OUT / "segs" / f"{sid}.mp4"
    vf = (f"scale=2112:1188,zoompan=z='1+0.03*on/{n}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={n}:s={W}x{H}:fps={FPS}")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-i", str(OUT / "stills" / f"{sid}.png"), "-vf", vf, "-frames:v", str(n),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", str(seg)], check=True)
    lst.append(f"file '{seg}'")
(OUT / "concat.txt").write_text("\n".join(lst))
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(OUT / "concat.txt"), "-c", "copy", str(OUT / "video4.mp4")], check=True)
ev = [{"t": round(t0, 3), "type": "pop4", "id": sid} for sid, t0, t1, f in seq if t0 > .1]
(HERE / "events_v4.json").write_text(json.dumps({"dur": T["dur"], "ev": ev}, indent=1))
print(f"{len(seq)} stills, {len(set(missing))} placeholders, {T['dur']:.1f}s → {OUT / 'video4.mp4'}")

"""v2 timeline: one voice take per paragraph, shots (beats) cut on the sentence where they start.

Reads voice2/{dur,words}.json + beats.json. Writes timeline2.json (page, mix) and cues2.json (srt).
A beat with no text (a checklist tick) becomes a hold after its paragraph.
"""
import json, re
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
LEAD, GAP, CH_GAP, HOLD, TITLE_AFTER, TITLE_HOLD, END_HOLD = .8, .4, 1.0, 3.2, "P02", 4.2, 4.0
MAX_CHARS = 78
beats = json.loads((HERE / "beats.json").read_text())
lines = {x["id"]: x for x in json.loads((HERE / "voice2/lines.json").read_text())}
dur = json.loads((HERE / "voice2/dur.json").read_text())
words = json.loads((HERE / "voice2/words.json").read_text())


def chunks_of(text):
    out = []
    for p in re.split(r"(?<=[.?!:])\s+", text):
        n = -(-len(p) // MAX_CHARS)
        while n > 1:
            ideal = len(p) / n
            cands = [m.end() for m in re.finditer(r"\s", p)]
            commas = [c for c in cands if p[c - 2] in ",;:" and abs(c - ideal) < 18]
            cut = min(commas or cands, key=lambda c: abs(c - ideal))
            out.append(p[:cut].strip()); p = p[cut:].strip(); n -= 1
        if p: out.append(p)
    merged = []
    for c in out:
        if merged and len(merged[-1]) < 22 and len(merged[-1]) + len(c) < MAX_CHARS + 10: merged[-1] += " " + c
        else: merged.append(c)
    return merged


def snap(ws, i):
    """best cut point near word index i: the word after the longest pause"""
    lo, hi = max(1, i - 3), min(len(ws) - 1, i + 3)
    if lo > hi: return max(0, min(i, len(ws) - 1))
    return max(range(lo, hi + 1), key=lambda j: (ws[j][1] - ws[j - 1][2]) - abs(j - i) * .02)


paras = []
for b in beats:
    if not paras or paras[-1]["id"] != b["para"]: paras.append({"id": b["para"], "chapter": b["chapter"], "beats": []})
    paras[-1]["beats"].append(b)

t, shots, cues, chapters, title, prev_ch = LEAD, [], [], [], None, None
for p in paras:
    if prev_ch is not None and p["chapter"] != prev_ch: t += CH_GAP
    if p["chapter"] != prev_ch and not p["chapter"].startswith("TITLE"): chapters.append({"name": p["chapter"], "t0": round(t, 3)})
    prev_ch = p["chapter"]
    ws, d = words.get(p["id"], []), dur[p["id"]]
    spoken = [b for b in p["beats"] if b["text"]]; tails = [b for b in p["beats"] if not b["text"]]
    total = sum(len(b["text"].split()) for b in spoken); acc = 0; starts = []
    for k, b in enumerate(spoken):
        if k == 0 or not ws: starts.append(0.0 if k == 0 else acc / total * d)
        else: j = snap(ws, round(acc / total * len(ws))); starts.append(max(0.0, ws[j][1] - .12))
        acc += len(b["text"].split())
    p0 = t
    for k, b in enumerate(spoken):
        a = p0 + starts[k]; e = p0 + (starts[k + 1] if k + 1 < len(spoken) else d)
        shots.append({"id": b["id"], "para": p["id"], "chapter": p["chapter"], "visual": b["visual"], "t0": round(a, 3), "v1": round(e, 3)})
        # subtitles: split the beat's words proportionally over the chunks
        ch = chunks_of(b["sub"]); n = sum(len(c.split()) for c in ch); c_acc = 0
        for c in ch:
            ca = a + (e - a) * c_acc / n; c_acc += len(c.split()); ce = a + (e - a) * c_acc / n
            cues.append({"t0": round(ca, 3), "t1": round(ce, 3), "text": c})
    t = p0 + d
    for b in tails:
        shots.append({"id": b["id"], "para": p["id"], "chapter": p["chapter"], "visual": b["visual"], "t0": round(t + .2, 3), "v1": round(t + HOLD, 3)})
        t += HOLD
    t += GAP
    if p["id"] == TITLE_AFTER:
        title = {"t0": round(t, 3), "t1": round(t + TITLE_HOLD, 3)}
        shots.append({"id": "TITLE", "para": "", "chapter": "TITLE", "visual": "title", "t0": title["t0"], "v1": title["t1"]})
        t += TITLE_HOLD

total_dur = round(t - GAP + END_HOLD, 3)
shots.sort(key=lambda s: s["t0"])
for i, s in enumerate(shots):                     # a shot lasts until the next one starts
    s["s0"] = 0.0 if i == 0 else shots[i - 1]["s1"]
    s["s1"] = round(shots[i + 1]["t0"] if i + 1 < len(shots) else total_dur, 3)
paras_t = []
for p in paras:
    sp = [s for s in shots if s["para"] == p["id"]]
    paras_t.append({"id": p["id"], "t0": sp[0]["t0"] if sp else 0})
(HERE / "timeline2.json").write_text(json.dumps({"dur": total_dur, "title": title, "chapters": chapters, "shots": shots,
                                                  "paras": [{"id": p["id"], "t0": min(s["t0"] for s in shots if s["para"] == p["id"])} for p in paras]}, indent=1))
(HERE / "cues2.json").write_text(json.dumps(cues, indent=1))
print(f"{len(shots)} shots, {len(cues)} cues, {total_dur:.1f} s ({int(total_dur // 60)}:{int(total_dur % 60):02})")

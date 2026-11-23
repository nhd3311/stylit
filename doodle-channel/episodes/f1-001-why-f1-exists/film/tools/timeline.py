"""Build the film timeline from the voice durations: line times, title card, subtitle chunks.

Writes timeline.json (read by index.html, mix.py) and cues.json (for core/render/srt.py).
"""
import json, re
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
LEAD, GAP, CH_GAP, TITLE_AFTER, TITLE_HOLD, END_HOLD = 0.8, 0.55, 1.1, "L05", 4.2, 4.0
MAX_CHARS = 78

lines = json.loads((HERE / "lines_raw.json").read_text())
dur = json.loads((HERE / "voice/dur.json").read_text())
words = json.loads((HERE / "voice/words.json").read_text())


def chunks_of(text):
    parts = re.split(r"(?<=[.?!:])\s+", text)
    out = []
    for p in parts:
        n = -(-len(p) // MAX_CHARS)          # pieces needed, then cut each near its ideal length
        while n > 1:
            ideal = len(p) / n
            cands = [m.end() for m in re.finditer(r"[,;:]\s|\s", p)]
            commas = [c for c in cands if p[c - 2] in ",;:" and abs(c - ideal) < 18]
            cut = min(commas or cands, key=lambda c: abs(c - ideal))
            out.append(p[:cut].strip()); p = p[cut:].strip(); n -= 1
        if p:
            out.append(p)
    merged = []                               # a tiny piece ("Up front:") joins the next one
    for c in out:
        if merged and len(merged[-1]) < 22 and len(merged[-1]) + len(c) < MAX_CHARS + 10:
            merged[-1] += " " + c
        else:
            merged.append(c)
    return merged


def chunk_times(line_id, chunks, t0, d):
    """Map chunk boundaries onto Whisper word times by word-count proportion."""
    ws = words.get(line_id) or []
    n_sub = sum(len(c.split()) for c in chunks)
    res, acc = [], 0
    for c in chunks:
        a, acc = acc, acc + len(c.split())
        if ws:
            i0 = min(len(ws) - 1, round(a / n_sub * len(ws)))
            i1 = min(len(ws) - 1, max(i0, round(acc / n_sub * len(ws)) - 1))
            s, e = max(0.0, ws[i0][1]), min(d, ws[i1][2])
        else:
            s, e = a / n_sub * d, acc / n_sub * d
        res.append([t0 + s, t0 + e, c])
    # continuous: each chunk holds until the next starts, the last until line end + 0.4 s
    for i, r in enumerate(res):
        r[1] = res[i + 1][0] if i + 1 < len(res) else t0 + d + 0.4
    return [{"t0": round(a, 3), "t1": round(b, 3), "text": c} for a, b, c in res]


t, out, chapters, title, prev_ch = LEAD, [], [], None, None
for x in lines:
    if prev_ch is not None and x["ch"] != prev_ch:
        t += CH_GAP
    if x["ch"] != prev_ch:
        chapters.append({"ch": x["ch"], "name": x["chapter"], "t0": round(t, 3)})
    d = dur[x["id"]]
    out.append({**x, "t0": round(t, 3), "t1": round(t + d, 3), "dur": d,
                "chunks": chunk_times(x["id"], chunks_of(x["sub"]), t, d)})
    t += d + GAP
    if x["id"] == TITLE_AFTER:
        title = {"t0": round(t, 3), "t1": round(t + TITLE_HOLD, 3)}
        t += TITLE_HOLD
    prev_ch = x["ch"]

total = round(t - GAP + END_HOLD, 3)
# each line's scene runs until the next line (or title card / end) begins
for i, x in enumerate(out):
    nxt = out[i + 1]["t0"] if i + 1 < len(out) else total
    if title and x["id"] == TITLE_AFTER:
        nxt = title["t0"]
    x["s0"] = 0.0 if i == 0 else round(out[i - 1]["s1"], 3) if out[i - 1]["id"] != TITLE_AFTER else title["t1"]
    x["s1"] = round(nxt, 3)

(HERE / "timeline.json").write_text(json.dumps({"dur": total, "title": title, "chapters": chapters, "lines": out}, indent=1))
cues = [c for x in out for c in x["chunks"]]
(HERE / "cues.json").write_text(json.dumps(cues, indent=1))
print(f"{len(out)} lines, {len(cues)} subtitle cues, {total:.1f} s ({int(total // 60)}:{int(total % 60):02})")

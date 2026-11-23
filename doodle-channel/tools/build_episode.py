#!/usr/bin/env python3
"""Turn an episode's scenes.json into everything needed for production.

Usage:
    python3 doodle-channel/tools/build_episode.py doodle-channel/episodes/001-how-humans-told-time

Outputs (written to <episode>/build/):
    script.md            readable script, by chapter, with scene ids + timings
    elevenlabs/*.txt     one clean narration file per chapter (+ full.txt)
    prompts.txt          one image prompt per scene, with the target filename
    scenes.csv           edit sheet: id, timing, narration, overlay, image, prompt
    captions.srt         estimated subtitles (re-sync after the real voiceover)
    chapters.txt         YouTube chapter timestamps for the description

Timings are ESTIMATES at ~150 words per minute. After ElevenLabs, let the real
audio decide: CapCut/Premiere auto-captions will replace captions.srt.
"""

import csv
import json
import re
import sys
from pathlib import Path

# Keep in sync with doodle-channel/style-guide.md
STYLE_LOCK = (
    "Minimalist hand-drawn stick-figure doodle illustration, thick black marker "
    "lines on a clean off-white paper background, flat and simple shapes, a single "
    "accent color (warm red) used sparingly, no shading, no gradients, no realistic "
    "details, no text, no letters, no watermark, wide 16:9 composition with empty "
    "space around the subject."
)
MASCOT = (
    'The main character "Doodle": a simple stick figure with a perfectly round head, '
    "two dot eyes, a small curved smile, and a red scarf — the only red thing on him."
)

WORDS_PER_SECOND = 2.5  # ~150 wpm narration
MIN_SCENE_SECONDS = 3.0
SCENE_GAP = 0.3
CHAPTER_GAP = 1.0
CAPTION_MAX_WORDS = 9


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def ts_srt(seconds):
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def ts_short(seconds):
    m, s = divmod(int(seconds), 60)
    return f"{m}:{s:02}"


def caption_chunks(text):
    """Split narration into short caption lines, breaking at punctuation when possible."""
    words = text.split()
    chunks, current = [], []
    for word in words:
        current.append(word)
        at_break = word[-1] in ".,?!;:—" or word == "—"
        if len(current) >= CAPTION_MAX_WORDS or (at_break and len(current) >= 4):
            chunks.append(" ".join(current))
            current = []
    if current:
        chunks.append(" ".join(current))
    return chunks


def build(episode_dir):
    data = json.loads((episode_dir / "scenes.json").read_text())
    out = episode_dir / "build"
    (out / "elevenlabs").mkdir(parents=True, exist_ok=True)

    scenes = []
    t = 0.0
    chapter_starts = []
    for ci, chapter in enumerate(data["chapters"], start=1):
        if ci > 1:
            t += CHAPTER_GAP
        chapter_starts.append((t, chapter["name"]))
        for si, scene in enumerate(chapter["scenes"], start=1):
            words = len(scene["narration"].split())
            duration = max(MIN_SCENE_SECONDS, words / WORDS_PER_SECOND)
            sid = f"{ci:02}-{si:02}"
            prompt = " ".join(
                [STYLE_LOCK, MASCOT if scene.get("mascot") else "", f"Scene: {scene['visual']}."]
            ).replace("  ", " ")
            scenes.append(
                {
                    "id": sid,
                    "chapter": chapter["name"],
                    "start": t,
                    "end": t + duration,
                    "words": words,
                    "narration": scene["narration"],
                    "overlay": scene.get("overlay", ""),
                    "image": f"{sid}.png",
                    "prompt": prompt,
                }
            )
            t += duration + SCENE_GAP

    total_words = sum(s["words"] for s in scenes)
    total_seconds = scenes[-1]["end"]

    # script.md
    lines = [f"# {data['title']}", "", f"_{len(scenes)} scenes · {total_words} words · ~{ts_short(total_seconds)} estimated_", ""]
    for start, name in chapter_starts:
        lines += [f"## [{ts_short(start)}] {name}", ""]
        for s in (s for s in scenes if s["chapter"] == name):
            overlay = f"  \n  _Overlay: **{s['overlay']}**_" if s["overlay"] else ""
            lines.append(f"- `{s['id']}` {s['narration']}{overlay}")
        lines.append("")
    (out / "script.md").write_text("\n".join(lines))

    # ElevenLabs: one file per chapter, paragraph per scene
    full = []
    for ci, (_, name) in enumerate(chapter_starts, start=1):
        text = "\n\n".join(s["narration"] for s in scenes if s["chapter"] == name)
        (out / "elevenlabs" / f"{ci:02}-{slug(name)}.txt").write_text(text + "\n")
        full.append(text)
    (out / "elevenlabs" / "full.txt").write_text('\n\n<break time="1.0s" />\n\n'.join(full) + "\n")

    # prompts.txt
    (out / "prompts.txt").write_text(
        "\n\n".join(f"[{s['image']}]\n{s['prompt']}" for s in scenes) + "\n"
    )

    # scenes.csv (utf-8-sig so Excel/Google Sheets open the em dashes correctly)
    with open(out / "scenes.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["id", "chapter", "start", "end", "seconds", "narration", "overlay", "image", "prompt"])
        for s in scenes:
            w.writerow([s["id"], s["chapter"], ts_short(s["start"]), ts_short(s["end"]),
                        round(s["end"] - s["start"], 1), s["narration"], s["overlay"], s["image"], s["prompt"]])

    # captions.srt — split each scene's time across its caption chunks by word count
    srt, n = [], 1
    for s in scenes:
        chunks = caption_chunks(s["narration"])
        cursor = s["start"]
        span = s["end"] - s["start"]
        for chunk in chunks:
            length = span * len(chunk.split()) / s["words"]
            srt.append(f"{n}\n{ts_srt(cursor)} --> {ts_srt(cursor + length)}\n{chunk}\n")
            cursor += length
            n += 1
    (out / "captions.srt").write_text("\n".join(srt))

    # chapters.txt
    (out / "chapters.txt").write_text(
        "\n".join(f"{ts_short(start)} {name}" for start, name in chapter_starts) + "\n"
    )

    print(f"{data['title']}: {len(scenes)} scenes, {total_words} words, ~{ts_short(total_seconds)} -> {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(Path(sys.argv[1]))

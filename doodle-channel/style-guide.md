# Visual Style Guide — Stick-Doodle Channel

Every image prompt = **STYLE LOCK** + (**MASCOT** if he's in the scene) + scene description.
Never change the style lock between scenes or episodes — consistency is the brand.

## STYLE LOCK (paste at the start of every prompt)

```
Minimalist hand-drawn stick-figure doodle illustration, thick black marker lines on a clean off-white paper background, flat and simple shapes, a single accent color (warm red) used sparingly, no shading, no gradients, no realistic details, no text, no letters, no watermark, wide 16:9 composition with empty space around the subject.
```

## MASCOT — "Doodle"

```
The main character "Doodle": a simple stick figure with a perfectly round head, two dot eyes, a small curved smile, and a red scarf — the only red thing on him.
```

Doodle is the narrator-avatar. He travels through history, reacts (shocked, confused, proud), and makes complex ideas feel human.

## Rules

| Rule | Why |
|---|---|
| No text inside generated images | AI text is often misspelled. Add titles/labels in the editor. |
| One idea per image | Viewers have ~6–8 seconds per scene. |
| Same red accent every time | Instant channel recognition, and it guides the eye. |
| Real people = stick figures with **one** identifying prop (Galileo + telescope, Harrison + pocket watch) | Avoids fake "portraits" and keeps the style. |
| Change the visual every 5–10 seconds | Retention. Use zoom/pan (Ken Burns) on longer scenes. |

## Editing defaults (CapCut / Premiere)

- 1920×1080, 30 fps
- Each image: slow zoom 100% → 108% over its duration
- Transitions: hard cuts inside a chapter, a quick "paper swipe" between chapters
- Font for overlays: a hand-written style (e.g. *Patrick Hand*, *Kalam*, *Gochi Hand*), black with red highlights
- Music: soft lo-fi / light pizzicato at around -24 dB under the voice
- Sound effects: pencil scribble when a scene appears, "ding" on big facts

## ElevenLabs defaults

- Model: Multilingual v2 (stable, supports `<break time="1.0s" />` pauses)
- Voice: calm, warm male or female narrator (pick one and keep it for every episode)
- Stability ≈ 0.45 · Similarity ≈ 0.75 · Style ≈ 0.15 · Speaker boost: on
- Generate **chapter by chapter**, not the whole script at once. Easier to re-do one part, fewer weird intonations.

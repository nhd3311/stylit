# Doodle Channel — production kit

A long-form (8–12 min) English YouTube channel: stick-doodle explainers on facts and life knowledge, from ancient times to today.
Scripts and scene images are AI-generated → reviewed by a human → voiced with ElevenLabs → edited to the script.

> Self-contained folder. It has nothing to do with the FitCheck app in the rest of this repo.

## Layout

```
doodle-channel/
├── style-guide.md                  # v1 style (plain doodle) + editing/ElevenLabs defaults
├── character/
│   ├── pip.md                      # v2: host "Pip", risograph style, STYLE/PIP LOCK, Google Flow prompts
│   └── pip-concept.svg/.png        # rough concept sketch (not final art)
├── tools/build_episode.py          # scenes.json → prompts, voice text, CSV, SRT, chapters
└── episodes/
    ├── 001-why-ai-animal-memes-go-viral/
    │   └── script-v1.md            # researched script, waiting for approval
    └── 002-how-humans-told-time/
        ├── script-v2.md            # researched rewrite, waiting for approval
        ├── scenes.json             # v1 scenes (to be regenerated from script-v2 after approval)
        ├── fact-check.md           # v1 fact table
        ├── youtube-metadata.md     # titles, thumbnail ideas, description, tags
        └── build/                  # generated, don't edit by hand
```

## Workflow for one episode

1. **Write `scenes.json`.** One scene = 1–2 sentences of narration (~5–10 s) + one visual idea.
2. **Build:**
   ```bash
   python3 doodle-channel/tools/build_episode.py doodle-channel/episodes/<episode-folder>
   ```
3. **Fact-check** with `fact-check.md`. Fix `scenes.json`, then rebuild.
4. **Images:** feed `build/prompts.txt` to your image model one by one (Gemini/Nano Banana, Ideogram, Midjourney…). Save each as the filename in brackets (`01-01.png`, …).
5. **Voice:** paste each `build/elevenlabs/NN-*.txt` into ElevenLabs (one chapter at a time), export MP3s.
6. **Edit:** put the MP3s on the timeline, then drop the images in order using `build/scenes.csv` as a guide (open it in Google Sheets). Add the overlay text from the `overlay` column.
7. **Captions & chapters:** auto-caption from the real audio (CapCut/Premiere), then update the chapter timestamps in the description.
8. **Upload** using `youtube-metadata.md`.

Timings in `build/` are estimated at ~150 words/min. The real voiceover decides the final timing.

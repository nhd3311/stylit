#!/bin/sh
# Rebuild "Why does F1 even exist?" from scratch: voice → timeline → events → picture → mix → subtitles → master.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LIB=${LIB:-$HOME/lemo-opuscar}
export LIB
[ -f "$LIB/core/render/video.mjs" ] || { echo "set LIB to the Lemo-Opuscar library folder"; exit 1; }
PY="$LIB/.venv/bin/python"
cd "$LIB"
[ -f "$HERE/voice/dur.json" ] || "$PY" core/tts/tts.py "$HERE/voice/lines.json" "$HERE/voice"   # Kokoro, bm_george
"$PY" core/tts/asr_check.py "$HERE/voice/lines.json" "$HERE/voice" --lang en || true            # spelling-only diffs (colour/color, digits) are expected
python3 "$HERE/tools/timeline.py"
node core/render/events.mjs "$HERE"
node core/render/video.mjs "$HERE" --fps 30 --workers ${WORKERS:-4} --out "$HERE/out/video.mp4"
"$PY" "$HERE/mix.py"
"$PY" core/render/srt.py "$HERE/cues.json" "$HERE/why-f1-exists.srt"
sh core/render/mux.sh "$HERE/out/video.mp4" "$HERE/out/mix.wav" "$HERE/out/why-f1-exists.mp4" 30 1

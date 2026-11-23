#!/bin/sh
# v4 (illustrated stills, reference-explainer style): images → edit → mix → master.  Re-runnable: finished images are kept.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); LIB=${LIB:-$HOME/lemo-opuscar}; export LIB
cd "$HERE"
python3 tools/frames_v4.py
[ -f gen/apex_ref.png ] || python3 tools/gen_images.py gen/pilot.json gen --only apex_ref --workers 1
python3 tools/gen_images.py gen/frames_ai.json gen/images --workers ${WORKERS:-4}
python3 tools/build_v4.py
EVENTS=events_v4.json OUTWAV=mix4.wav "$LIB/.venv/bin/python" mix2.py
sh "$LIB/core/render/mux.sh" out/v4/video4.mp4 out/mix4.wav out/how-a-newspaper-stunt-became-f1-v4.mp4 30 0

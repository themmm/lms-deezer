#!/bin/bash
# Headless test player "hr8-test": 24-bit output to stdout, up to 192 kHz, paced by pacer.py (bytes/s, env PACE, default 600000).
exec /Applications/LyrionPlay.app/Contents/MacOS/squeezelite -s 127.0.0.1 -o - -a 24 -r 192000 \
  -n hr8-test -m 02:00:00:00:00:08 2>/dev/null | python3 -I "$(dirname "$0")/pacer.py" "${PACE:-600000}"

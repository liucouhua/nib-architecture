#!/bin/bash
# Optional: render local PNG previews. PNGs are gitignored.

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -z "${DRAWIO:-}" ]]; then
  if command -v drawio >/dev/null 2>&1; then
    DRAWIO=drawio
  elif [[ -x /Applications/draw.io.app/Contents/MacOS/draw.io ]]; then
    DRAWIO=/Applications/draw.io.app/Contents/MacOS/draw.io
  else
    echo "draw.io CLI not found. Install the desktop app or set DRAWIO=..." >&2
    exit 1
  fi
fi

for name in module-map matching runtime add-package; do
  "$DRAWIO" -x -f png --width 1600 -o "$DIR/$name.png" "$DIR/$name.drawio"
done
echo "wrote pngs next to the .drawio files (gitignored)"

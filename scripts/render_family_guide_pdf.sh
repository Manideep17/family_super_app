#!/usr/bin/env bash
# Renders docs/FOR_FAMILIES_AND_TESTERS.pdf from docs/print/family_guide.html
# using Chrome/Chromium headless (no pandoc required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML="$ROOT/docs/print/family_guide.html"
OUT="$ROOT/docs/FOR_FAMILIES_AND_TESTERS.pdf"

if [[ ! -f "$HTML" ]]; then
  echo "Missing $HTML" >&2
  exit 1
fi

CHROME="${CHROME:-}"
if [[ -z "$CHROME" ]]; then
  if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  elif [[ -x "/Applications/Chromium.app/Contents/MacOS/Chromium" ]]; then
    CHROME="/Applications/Chromium.app/Contents/MacOS/Chromium"
  elif [[ -n "${CHROME_PATH:-}" ]]; then
    CHROME="$CHROME_PATH"
  fi
fi

if [[ -z "$CHROME" || ! -x "$CHROME" ]]; then
  echo "Could not find Chrome or Chromium for headless PDF." >&2
  echo "Install Google Chrome, or set CHROME to the browser binary path." >&2
  exit 1
fi

FILE_URL="file://${HTML}"
# Normalize to file:/// triple slash for absolute paths
if [[ "$HTML" == /* ]]; then
  FILE_URL="file://${HTML}"
fi

"$CHROME" \
  --headless=new \
  --disable-gpu \
  --no-pdf-header-footer \
  --print-to-pdf="$OUT" \
  "$FILE_URL"

echo "Wrote $OUT"

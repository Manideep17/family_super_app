#!/usr/bin/env bash
# Build a release APK. Requires Flutter on PATH or set FLUTTER=/path/to/flutter/bin/flutter
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_CMD="${FLUTTER:-flutter}"
if ! command -v "$FLUTTER_CMD" &>/dev/null; then
  for candidate in \
    "$HOME/flutter/bin/flutter" \
    "$HOME/development/flutter/bin/flutter" \
    "$HOME/sdk/flutter/bin/flutter" \
    "$HOME/fvm/default/bin/flutter"; do
    if [[ -x "$candidate" ]]; then
      FLUTTER_CMD="$candidate"
      break
    fi
  done
fi

if ! command -v "$FLUTTER_CMD" &>/dev/null && [[ ! -x "$FLUTTER_CMD" ]]; then
  echo "ERROR: Flutter not found."
  echo "Install: https://docs.flutter.dev/get-started/install/macos"
  echo "Then either add Flutter to your PATH, or run:"
  echo "  FLUTTER=/path/to/flutter/bin/flutter bash scripts/build_release_apk.sh"
  echo ""
  echo "Alternatively push this repo to GitHub and run the 'Build APK' workflow (see README)."
  exit 1
fi

echo "Using: $FLUTTER_CMD"
"$FLUTTER_CMD" --version
"$FLUTTER_CMD" pub get
"$FLUTTER_CMD" build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Done. Install this file on your phone:"
echo "  $APK"
ls -la "$APK"

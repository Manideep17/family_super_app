#!/usr/bin/env bash
# One-shot: dependencies, analyzer, release APK for phone sideload testing.
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
  echo "ERROR: Flutter not found. Install Flutter or set FLUTTER=/path/to/flutter/bin/flutter"
  exit 1
fi

echo "Using: $FLUTTER_CMD"
"$FLUTTER_CMD" pub get
dart analyze
# Optional: export DART_DEFINES_EXTRA='--dart-define=FUNCTIONS_ENABLED=true --dart-define=MEDIA_UPLOADS_ENABLED=true'
if [ -n "${DART_DEFINES_EXTRA:-}" ]; then
  echo "Extra dart defines: $DART_DEFINES_EXTRA"
fi
# shellcheck disable=SC2086
"$FLUTTER_CMD" build apk --release ${DART_DEFINES_EXTRA:-}

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Phone beta APK ready:"
echo "  $APK"
ls -la "$APK"
echo ""
echo "Share that file with testers; send them docs/BETA_TESTER_GUIDE.md"

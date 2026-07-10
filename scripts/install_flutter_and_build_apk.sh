#!/usr/bin/env bash
# Install Flutter (stable) to ~/flutter if missing, then build release APK.
# Requires: git, Android SDK (install Android Studio), JDK 17+.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
FLUTTER_BIN="$FLUTTER_HOME/bin/flutter"

export PATH="$FLUTTER_HOME/bin:$PATH"

if command -v flutter &>/dev/null && [[ "$(command -v flutter)" != "$FLUTTER_BIN" ]]; then
  echo "Using flutter from PATH: $(command -v flutter)"
elif [[ -x "$FLUTTER_BIN" ]]; then
  echo "Using Flutter at $FLUTTER_HOME"
else
  echo "Installing Flutter to $FLUTTER_HOME (stable, shallow clone)..."
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
  chmod +x "$FLUTTER_BIN" 2>/dev/null || true
  "$FLUTTER_BIN" doctor
fi

cd "$ROOT"
flutter --version
flutter pub get
flutter build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "APK ready:"
echo "  $APK"
ls -la "$APK"

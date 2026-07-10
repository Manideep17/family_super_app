#!/usr/bin/env bash
# Run from anywhere: installs CocoaPods deps and opens Xcode workspace.
# Uses the Flutter app root (directory with pubspec.yaml + ios/), never functions/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$ROOT/pubspec.yaml" ]] || [[ ! -d "$ROOT/ios" ]]; then
  echo "Expected Flutter root at $ROOT (need pubspec.yaml and ios/)." >&2
  exit 1
fi
cd "$ROOT"
echo "==> Flutter root: $ROOT"
flutter pub get
echo "==> pod install"
(cd ios && pod install)
echo "==> Opening Xcode workspace"
open "$ROOT/ios/Runner.xcworkspace"

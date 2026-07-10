#!/usr/bin/env bash
# Build release APK and upload to Firebase App Distribution.
# Requires: flutter, firebase CLI (`npm i -g firebase-tools`), `firebase login`,
# and App Distribution enabled for the Android app in the Firebase console.
#
# Usage:
#   ./scripts/distribute_android_app_distribution.sh
#   TESTERS="a@x.com,b@y.com" RELEASE_NOTES="Beta 3" ./scripts/distribute_android_app_distribution.sh
#   GROUPS="beta-families" RELEASE_NOTES="Beta 3" ./scripts/distribute_android_app_distribution.sh
#
# If GROUPS is non-empty, testers are taken from those App Distribution groups
# (create groups in Firebase console). Otherwise TESTERS (comma-separated emails) is used.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${JAVA_HOME:=/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
: "${GRADLE_USER_HOME:=$HOME/.gradle}"
export JAVA_HOME GRADLE_USER_HOME
export PATH="$JAVA_HOME/bin:$PATH"

# From android/app/google-services.json → mobilesdk_app_id
APP_ID="${APP_ID:-1:679019957650:android:8c6cb7576949211947c54b}"
TESTERS="${TESTERS:-manideepbiswas@gmail.com}"
GROUPS="${GROUPS:-}"
RELEASE_NOTES="${RELEASE_NOTES:-FAM Android release}"

echo "==> flutter build apk --release"
flutter build apk --release

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo "==> firebase appdistribution:distribute ($APK)"
if [ -n "$GROUPS" ]; then
  firebase appdistribution:distribute "$APK" \
    --app "$APP_ID" \
    --groups "$GROUPS" \
    --release-notes "$RELEASE_NOTES"
else
  firebase appdistribution:distribute "$APK" \
    --app "$APP_ID" \
    --testers "$TESTERS" \
    --release-notes "$RELEASE_NOTES"
fi

echo "Done. Open Firebase console → App Distribution for links and tester status."

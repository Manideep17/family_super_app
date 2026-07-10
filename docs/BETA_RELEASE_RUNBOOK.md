# Beta release runbook (FAM)

Android-first beta checklist. **iOS/TestFlight is out of scope** until you reopen that platform — validate every ship on **Android APK or AAB** testers actually install.

## 0) Before anyone installs

- **`android/app/google-services.json`** is present (from `flutterfire configure` or your Firebase download). Without it, the app will not talk to your Firebase project.
- **Release signing:** For Play Store or a **signed** APK beta, create `android/key.properties` and an upload keystore — see [RELEASE_SIGNING.md](RELEASE_SIGNING.md). Until then, release builds may still use the **debug** keystore (see `android/app/build.gradle.kts`).
- **Google Sign-In:** add the **SHA-1** (and SHA-256 if you use them) for the keystore that **signs the APK you ship**. From the repo root:

  ```bash
  cd android && ./gradlew signingReport
  ```

  Use the **release** variant after `key.properties` is set up, or the **debug** variant for debug-keystore builds. Paste into Firebase Console → Project settings → Android app **`com.family.superapp`**. OAuth can take a few minutes to propagate.

- Bump **`pubspec.yaml`** `version: x.y.z+build` when you ship a new APK so testers know which file is newest.

## 1) Deploy backend rules and indexes

From the **repository root** (same folder as `pubspec.yaml`):

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Use `firebase use <projectId>` first if you have multiple Firebase projects.

### 1b) Deploy Cloud Functions (recommended for reminders / digests / rollups)

From **`functions/`** (requires Blaze billing where Firebase Functions deployment expects it):

```bash
cd functions && npm ci && npm run build && cd ..
firebase deploy --only functions
```

Smoke expectations: digest (`dailyDigestOptIn` on family doc), FCM on `users/{uid}`, task/chat/diary triggers — see [BACKEND_INTEGRITY_AND_AI_GATE.md](BACKEND_INTEGRITY_AND_AI_GATE.md).

## 2) Build release APK

See also **build environment** in [section 2b](#2b-release-build-environment-cursor-ci) if Gradle fails in Cursor or CI.

```bash
flutter pub get
dart analyze
flutter build apk --release
```

Pass **`--dart-define`** when your beta needs uploads or Function-backed UI (see [SMOKE_TEST_CHECKLIST.md](SMOKE_TEST_CHECKLIST.md) `AppFlags` table), e.g.:

```bash
flutter build apk --release \
  --dart-define=FUNCTIONS_ENABLED=true \
  --dart-define=MEDIA_UPLOADS_ENABLED=true \
  --dart-define=CLOUDINARY_CLOUD_NAME=... \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=...
```

[`scripts/prep_phone_beta.sh`](../scripts/prep_phone_beta.sh) runs analyze then `flutter build apk --release`. Optionally export **`DART_DEFINES_EXTRA`** as a string of `--dart-define=KEY=value` tokens (space-separated), e.g. `--dart-define=FUNCTIONS_ENABLED=true`.

Or one script from repo root:

```bash
bash scripts/prep_phone_beta.sh
```

Output APK:

- `build/app/outputs/flutter-apk/app-release.apk`

### 2b) Release build environment (Cursor / CI)

Some environments set `GRADLE_USER_HOME` to a sandbox path (e.g. under `cursor-sandbox-cache`), which can break Gradle with missing `metadata.bin`.

**Fix:** use Android Studio’s bundled JDK and a stable Gradle home:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export GRADLE_USER_HOME="$HOME/.gradle"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --release
```

[`scripts/distribute_android_app_distribution.sh`](../scripts/distribute_android_app_distribution.sh) applies this pattern before upload.

## 3) Install APK locally for final sanity check

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 4) Smoke test before sharing

Run the full checklist on the **same artifact** you share: [SMOKE_TEST_CHECKLIST.md](SMOKE_TEST_CHECKLIST.md) (core steps + flag-dependent rows).

Quick spot-check if you are in a hurry:

- Sign in and confirm home shows your display name.
- Create family and copy invite code.
- Join family from second account.
- Send one chat message.
- Create one task and complete approval flow.
- Create one diary memory.

## 5) Seed demo data (optional but recommended)

Run after at least 2 members have joined the family:

```bash
cd functions && npm run seed:demo -- --join-code ABC123 --wipe-demo --service-account "/absolute/path/firebase-adminsdk.json"
```

Or use family id directly:

```bash
cd functions && npm run seed:demo -- --family-id <FAMILY_ID> --wipe-demo --service-account "/absolute/path/firebase-adminsdk.json"
```

This seeds sample chat messages, stories, tasks, events, and member stats.

### Safe auto-seed mode

If you want families to auto-seed only when explicitly enabled, set this field
on the family doc in Firestore:

- `families/{familyId}.demoMode = true`

Behavior:

- seeding runs only for families with `demoMode: true`
- waits until family has at least 2 members
- seeds once and marks `demoSeededAt`
- does not run for normal families unless you enable demo mode

## 6) If release is broken (rollback)

1. Re-share the previous known-good APK.
2. Re-deploy the last known-good Firestore rules/indexes.
3. Post a note to testers to reinstall with `adb install -r`.

## 7) Share with friends

- Send **`build/app/outputs/flutter-apk/app-release.apk`** (or upload via **[Firebase App Distribution](APPDIST_AND_PLAY.md)** with `scripts/distribute_android_app_distribution.sh`).
- Point testers at **[docs/BETA_TESTER_GUIDE.md](BETA_TESTER_GUIDE.md)** for install steps and Google sign-in troubleshooting.

## 8) Notes for this project

- Beta distribution mode is direct APK sharing.
- Family membership is open by invite code (no fixed seat cap).
- Media upload depends on build flags (`MEDIA_UPLOADS_ENABLED`) and Cloudinary defines.

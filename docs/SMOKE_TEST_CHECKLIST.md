# Smoke test checklist (same build testers use)

Run through this on the **exact APK or AAB** you will share (not only `flutter run` debug).

## Build flags (`AppFlags`)

These map to **`lib/core/config/app_flags.dart`**. Pass with Flutter **`--dart-define=KEY=value`** on `flutter build` / `flutter run`.

| Dart define | Default | When true / non-empty | Smoke focus |
|-------------|---------|-------------------------|-------------|
| `FUNCTIONS_ENABLED` | `false` | Callable / scheduled Functions features (weekly rollups, AI quiz path, leaderboard messaging) behave as enabled in UI | Deploy `functions/` (see below), then re-test **Insights / Best moments**, **Leaderboard**, **AI quiz** if you use them |
| `MEDIA_UPLOADS_ENABLED` | `false` | Same flag as legacy name: diary photos, avatar, vault, reel uploads via Cloudinary | Also set **`CLOUDINARY_CLOUD_NAME`** and **`CLOUDINARY_UPLOAD_PRESET`** |
| `CLOUDINARY_CLOUD_NAME` | `''` | Required with uploads | Create story with image, avatar change, vault add, reel record (with `MEDIA_UPLOADS_ENABLED=true`) |
| `CLOUDINARY_UPLOAD_PRESET` | `''` | Required with uploads | Same row |
| `ONESIGNAL_APP_ID` | `''` | Optional OneSignal bridge (see [`lib/core/fcm/fcm_bootstrap.dart`](../lib/core/fcm/fcm_bootstrap.dart), [`free_push_bridge.dart`](../lib/core/push/free_push_bridge.dart)) | With worker URL/key: verify push reaches device |
| `PUSH_WORKER_ENDPOINT` | `''` | Bridge HTTP endpoint | Same |
| `PUSH_WORKER_KEY` | `''` | Shared secret header | Same |

**Example release build with Functions + media:**

```bash
flutter build apk --release \
  --dart-define=FUNCTIONS_ENABLED=true \
  --dart-define=MEDIA_UPLOADS_ENABLED=true \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset
```

## Firebase Functions (reliability)

Automated digest, rollups, and triggers live under [`functions/`](../functions/). After code changes deploy from the **`functions`** directory (`npm run build && firebase deploy --only functions` or your CI). Smoke expectations:

- **`scheduledFamilyDigest`** — owner-enabled digest (`dailyDigestOptIn` on the family doc); requires valid FCM token on **`users/{uid}`**.
- **Task / diary / chat** triggers — parity with README “automated reminders” stance; scan [docs/BACKEND_INTEGRITY_AND_AI_GATE.md](BACKEND_INTEGRITY_AND_AI_GATE.md) if delivery is flaky.

Always deploy **`firestore.rules`** and **`firestore.indexes.json`** when repo rules/indexes changed ([docs/FIREBASE_SETUP.md](FIREBASE_SETUP.md)).

## Core smoke steps

| Step | Action | Pass |
|------|--------|------|
| 1 | Install fresh or clear app data | |
| 2 | Sign in: email/password **or** Google | |
| 3 | **Create family** — name + member profile | |
| 4 | Copy **invite code** from My family | |
| 5 | Sign out; sign in as second account (or second device) | |
| 6 | **Join** with 6-character code | |
| 7 | **Chat** — send and receive a message | |
| 8 | **Tasks** — create, assignee completes, approver approves if applicable | |
| 9 | **Diary** — new memory appears in feed | |
| 10 | **Home** — refresh; optional: poll, announcement | |
| 11 | **Sign out** and sign back in — family still loads | |

### Optional (flag-dependent)

| Step | Action | Pass |
|------|--------|------|
| 12 | With **`MEDIA_UPLOADS_ENABLED`** + Cloudinary: diary image, profile photo, vault photo | |
| 13 | With **`FUNCTIONS_ENABLED`** + deployed Functions: open flows that call Functions (e.g. best moments / leaderboard banners) — no unexplained blank or error loops | |
| 14 | **Future predictions** — second member votes yes/no; author resolves after target date (**rules** enforce vote/reaction patches only on own uid) | |
| 15 | **Mini reel** (with uploads): react with emoji | |

**Moderation:** As family **owner**, open **My family → Reports inbox** after submitting a report from another screen (indexes + rules deployed).

**Release builds:** After configuring [RELEASE_SIGNING.md](RELEASE_SIGNING.md), repeat on `flutter build apk --release` (or app bundle) and confirm **Google Sign-In** works (Firebase SHA registered for that keystore).

Record date, build version (`pubspec.yaml`), device model, and **`--dart-define`** set you used for your notes.

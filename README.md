# FAM (Family Super App)

Private family app: **Flutter + Firebase**, Clean Architecture, **Riverpod**, **go_router**.

## Prerequisites (Android)

1. **Flutter SDK** (stable), e.g. [Install Flutter](https://docs.flutter.dev/get-started/install).
2. **JDK 17** (Android Studio bundles one, or use Temurin / Oracle).
3. **Android Studio** with Android SDK + at least one **virtual device** or a physical phone with **USB debugging**.

Check your machine:

```bash
flutter doctor -v
```

## One-time project setup

From this directory:

```bash
cd family_super_app
flutter pub get
```

If anything is still missing, let Flutter repair the scaffold:

```bash
flutter create . --project-name family_super_app
```

That keeps your `lib/` code and fills any platform files Gradle expects.

## Firebase (required before the app works)

1. Create a Firebase project and register **Android** and **iOS** apps with bundle / package id **`com.family.superapp`** (must match `android/app/build.gradle.kts` and Xcode **Runner** target).
2. Install [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) and run:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   This overwrites **`lib/core/firebase/firebase_options.dart`** and should download **`android/app/google-services.json`**.

3. In Firebase Console → **Authentication**, enable **Email/Password** and **Google**.
4. For **Google Sign-In on Android**, add your debug **SHA-1** (and release SHA-1 later):

   ```bash
   cd android && ./gradlew signingReport
   ```

   Paste the **SHA-1** under Project settings → Your apps → Android app.

5. Deploy **Firestore rules and indexes** (see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)).
6. Create a family in-app, then share the 6-character invite code with members.

Sample document shapes: [docs/SAMPLE_DATA.md](docs/SAMPLE_DATA.md).

## Run on Android

```bash
flutter run
# or pick a device
flutter devices
flutter run -d <deviceId>
```

## Build a release APK (starters)

Uses the **debug** keystore for signing (fine for sideloading; use a real keystore for Play Store).

**Option A — install Flutter (if needed) and build in one go:**

```bash
cd family_super_app
bash scripts/install_flutter_and_build_apk.sh
```

This clones stable Flutter to **`~/flutter`** (or set **`FLUTTER_HOME`**) if `flutter` is not already on your `PATH`. You still need **Android Studio** (SDK + licenses) and **JDK 17** for the APK step.

**Option B — Flutter already installed (quick phone beta):**

```bash
bash scripts/prep_phone_beta.sh
```

Or manually:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export GRADLE_USER_HOME="$HOME/.gradle"
flutter build apk --release
```

IDEs and CI sandboxes sometimes set `GRADLE_USER_HOME` to a transient cache; if Gradle errors with missing `metadata.bin`, force `GRADLE_USER_HOME` to `$HOME/.gradle` as above (see also `scripts/distribute_android_app_distribution.sh`).

Output: `build/app/outputs/flutter-apk/app-release.apk`.

**Option C — no local Flutter:** put this folder in a **GitHub** repo (repo root = this project, so `pubspec.yaml` is at the root). GitHub will run [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml): open **Actions → Build APK → Run workflow** and optionally enable **Functions** / **media uploads** toggles for `AppFlags`, or push to `main`/`master` for a default build, then download the **app-release-apk** artifact and unzip to get the APK.

## Navigation

- **Bottom tabs:** Home (dashboard), Chat, Diary, Tasks  
- **Drawer:** My profile, family roster, timeline, calendar, vault, leaderboard, predictions, games, sign out  
- **Games hub:** Who said, Memory match, Know your family, Time travel, Creative challenge; puzzle / reel / others marked coming soon  

## Original spec — what’s in vs backlog

**In the app today:** Clean architecture, Riverpod, Firebase Auth/Firestore/FCM bootstrap, family create/join by invite code, member-to-member tasks with approval (including **optional “thanks in family chat”** after approve), diary/timeline/calendar/vault, gamification + predictions, personalized **Home** dashboard, **profile + avatar**, **FCM token** on `users/{uid}`, **Time travel** and **Creative challenge** games with small point rewards.

**Still backend or future work:** Fully automated push/reminders (without manual trigger paths), AI “smart” features (Phase 4), family puzzle / mini-reel / voting-heavy games, stricter anti-cheat controls for points.

## Current engineering priority

**iOS (TestFlight / App Store) is deferred** — ship and validate on **Android** only for now; the iOS section below is reference for when you reopen the platform.

**Reliability (Android):** deploy **Cloud Functions** (FCM digests, rollups, task/chat/diary triggers), deploy **Firestore rules + indexes**, keep **FCM tokens** fresh on `users/{uid}`, and ship release APK/AAB with the right **`--dart-define`** flags (see [docs/SMOKE_TEST_CHECKLIST.md](docs/SMOKE_TEST_CHECKLIST.md) and [docs/BETA_RELEASE_RUNBOOK.md](docs/BETA_RELEASE_RUNBOOK.md)). **Trust** (moderation inbox, game doc rules) — [docs/MODERATION_AND_EDITS.md](docs/MODERATION_AND_EDITS.md). **Phase 4 AI** — [docs/PHASE4_AI_GATE.md](docs/PHASE4_AI_GATE.md).

## Docs

- [docs/HTTPS_APP_LINKS.md](docs/HTTPS_APP_LINKS.md) — **https** invite links (**Android App Links** + `assetlinks.json` first; iOS Universal Links deferred)  
- [docs/APPDIST_AND_PLAY.md](docs/APPDIST_AND_PLAY.md) — **Firebase App Distribution** groups, **Play closed testing**, HTTPS checklist; pairs with [`scripts/distribute_android_app_distribution.sh`](scripts/distribute_android_app_distribution.sh)  
- [docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md) — **Android release keystore**, `key.properties`, Firebase SHA for Google Sign-In  
- [docs/SMOKE_TEST_CHECKLIST.md](docs/SMOKE_TEST_CHECKLIST.md) — smoke pass on the **same build** you share with testers  
- [docs/FOR_FAMILIES_AND_TESTERS.md](docs/FOR_FAMILIES_AND_TESTERS.md) — **for families & beta testers:** what the app does, how to sign in, new features (announcements, polls, coins/titles), privacy in plain language · [PDF export](docs/FOR_FAMILIES_AND_TESTERS.pdf) (run `bash scripts/render_family_guide_pdf.sh` to regenerate)
- [docs/FAM_KEEPING_FAMILIES_CLOSER.html](FAM_KEEPING_FAMILIES_CLOSER.html) — poster-style “why FAM” (open in browser; print to PDF); [JPG export](FAM_KEEPING_FAMILIES_CLOSER.jpg)  
- [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) — products, rules, indexes  
- [docs/MODERATION_AND_EDITS.md](docs/MODERATION_AND_EDITS.md) — **owner reports inbox**, local hide-after-report, **who can edit** family-wide fields (audit)  
- [docs/BACKEND_INTEGRITY_AND_AI_GATE.md](docs/BACKEND_INTEGRITY_AND_AI_GATE.md) — **FCM/digest** expectations, callable escape hatch if abuse, **Phase 4** gate pointer  
- [docs/BETA_RELEASE_RUNBOOK.md](docs/BETA_RELEASE_RUNBOOK.md) — your checklist before sharing an APK with friends  
- [docs/BETA_TESTER_GUIDE.md](docs/BETA_TESTER_GUIDE.md) — forward this to testers (install + feedback)  
- [docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md)  
- [docs/REVAMP_ROADMAP.md](docs/REVAMP_ROADMAP.md) — $0-budget design/gamification/AI revamp: what's shipped, what's next  
- [docs/AI_LOGIC_SETUP.md](docs/AI_LOGIC_SETUP.md) — unblock Cloud Functions (Blaze, capped at $0) and the free Gemini weekly digest (Spark, no billing) — two separate steps
- [docs/PLAY_STORE_LAUNCH_CHECKLIST.md](docs/PLAY_STORE_LAUNCH_CHECKLIST.md) — what's done vs. what's left before Play Store submission
- [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) / [docs/privacy-policy.html](docs/privacy-policy.html) — hostable privacy policy
- [docs/PLAY_STORE_DATA_SAFETY.md](docs/PLAY_STORE_DATA_SAFETY.md) — Play Console Data Safety form answer key
- [docs/delete-account.html](docs/delete-account.html) — account/data deletion request page (also see Profile → Danger zone in-app)
- [store_listing/STORE_LISTING.md](store_listing/STORE_LISTING.md) — store copy, icon, feature graphic  

## iOS (TestFlight / App Store) — deferred

_Not a current ship target — focus stays on Android betas._

The repo includes an **`ios/`** Xcode project when you reopen iOS work. Bundle ID is **`com.family.superapp`** (matches `lib/firebase_options.dart` and Firebase). `GoogleService-Info.plist` is under `ios/Runner/` (regenerate from Firebase if you rotate keys).

### Requirements on your Mac

1. Install **full Xcode** from the Mac App Store (not only “Command Line Tools”). `flutter build ios` and `xcodebuild` need the real Xcode app; set the active developer directory:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

2. Register the **iOS** app in Firebase (same project) with bundle ID **`com.family.superapp`**, download **`GoogleService-Info.plist`**, and replace `ios/Runner/GoogleService-Info.plist` if Firebase shows different OAuth / keys.

3. In Firebase **Authentication → Sign-in method → Google**, ensure the **iOS** URL scheme / OAuth client matches (Google Sign-In uses the URL scheme in `Info.plist`).

### CocoaPods (first time)

Run these from the **Flutter app root** — the folder that contains **`pubspec.yaml`** and **`ios/`** (e.g. `.../family_super_app/`). **Do not** run from `functions/`; there is no `ios` folder there, so `cd ios` will fail.

```bash
cd /path/to/family_super_app   # must contain pubspec.yaml + ios/
flutter pub get
cd ios && pod install && cd ..
```

Or use the helper (works no matter which shell directory you start from, as long as you invoke the script by path):

```bash
bash scripts/ios_prep.sh
```

### Run on simulator or device

```bash
flutter devices
flutter run -d ios
```

### Archive for testers (TestFlight)

1. Open **`ios/Runner.xcworkspace`** in Xcode (always the `.xcworkspace`, not `.xcodeproj`).
2. Select the **Runner** target → **Signing & Capabilities**: choose your **Team**, enable **Automatically manage signing**.
3. Menu **Product → Archive**, then **Distribute App** → **App Store Connect** → **Upload** (or TestFlight internal testing).

### CLI release build (after Xcode works)

```bash
flutter build ipa --release
```

Output is under `build/ios/ipa/`. You still need a valid Apple Developer Program membership and App Store Connect app record.

## Web (optional demo)

`lib/firebase_options.dart` includes **web**, but FAM is built and tested primarily for **Android** (and optionally iOS). Treat **web as a quick demo only**: run `flutter run -d chrome` from the app root. **Firebase Storage uploads**, some auth flows, and performance may differ from mobile—do not promise feature parity to families until you invest in web UX.

## Phases

- **Phase 1:** Auth, chat, diary, tasks  
- **Phase 2:** Timeline, calendar, vault, FCM token + permission (server push still needs Functions)  
- **Phase 3:** Gamification, predictions, games hub (incl. time travel + creative challenge), home dashboard, profile/avatar  
- **Phase 4 (not in repo):** AI highlights, mood analytics, automated “best moments” — treat as a separate epic; see [docs/PHASE4_AI_GATE.md](docs/PHASE4_AI_GATE.md) before investing.


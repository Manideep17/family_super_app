# Play Store launch checklist — FAM

Everything needed to submit FAM to the Play Store, split into what's built and what only
you can do (Play Console access, real credentials, and an actual device/build environment
aren't available in this sandbox).

## ✅ Done this pass

| Item | Where |
|---|---|
| Privacy policy (markdown + hosted HTML) | `docs/PRIVACY_POLICY.md`, `docs/privacy-policy.html` |
| Data Safety form mapping | `docs/PLAY_STORE_DATA_SAFETY.md` |
| Account deletion — Cloud Function | `functions/src/account.ts` (`deleteAccount`, compiles clean) |
| Account deletion — in-app UI | Profile → Danger zone, `lib/features/profile/presentation/screens/profile_screen.dart` |
| Account deletion — web request page | `docs/delete-account.html` |
| Landing page tying the above together | `docs/index.html` |
| Release upload keystore | `android/app/upload-keystore.jks` (real, generated in this session) |
| Signing config | `android/key.properties` (gitignored, matches `docs/RELEASE_SIGNING.md`) |
| App icon (fixes a real mismatch — legacy PNGs were a generic blue square while the adaptive icon was already a designed violet "F" mark) | `android/app/src/main/res/mipmap-*/ic_launcher.png` |
| Play Store listing icon (512×512) | `store_listing/play_store_icon_512.png` |
| Feature graphic (1024×500) | `store_listing/feature_graphic_1024x500.png` |
| Store listing copy (title, short/full description, what's new, category) | `store_listing/STORE_LISTING.md` |
| Target API level check | See below — no code change needed, contingent on your local Flutter version |

## 🔒 Before you push any of this to GitHub

- **`android/app/upload-keystore.jks` and `android/key.properties` are real secrets** —
  confirmed gitignored and untracked (`git status --porcelain` shows nothing for either).
  Back up `upload-keystore.jks` and the passwords in `key.properties` somewhere durable
  *outside* this repo (a password manager, an encrypted drive) — if you lose this file, you
  can never publish an update to this app again under the same listing. I generated the
  passwords randomly in this session; they're only saved in that one file, nowhere else.
- Replace `mandyapp17@gmail.com` in `docs/index.html`, `docs/delete-account.html`,
  and `docs/privacy-policy.html` (3 places total) with the address you want public. Use a
  personal one — this project is on your personal GitHub account, not Sandvik's.

## ⬜ Steps only you can do

1. **Deploy Cloud Functions**, including the new `deleteAccount` — via the
   `.github/workflows/deploy-firebase.yml` GitHub Action (needs the `FIREBASE_SERVICE_ACCOUNT`
   secret, see the workflow file's header comment) or `firebase deploy --only functions`
   locally. Until deployed, the in-app "Delete my account" button will show a clear error
   instead of silently failing.
2. **Enable GitHub Pages**: repo Settings → Pages → source: `main` branch, `/docs` folder.
   You'll get `https://Manideep17.github.io/family_super_app/` — use
   `https://Manideep17.github.io/family_super_app/privacy-policy.html` and
   `https://Manideep17.github.io/family_super_app/delete-account.html` in Play Console.
3. **Register the release keystore's fingerprint with Firebase** (needed for Google
   Sign-In to work in release builds): Firebase Console → Project settings → Your apps →
   Android `com.family.superapp` → add SHA-1 `16:03:55:FB:1B:A4:E0:6B:C3:14:AD:4E:20:C1:95:80:CF:6F:F4:44`
   and SHA-256 `50:2C:BF:C8:41:27:58:86:70:FC:B4:4C:8A:B9:07:ED:35:CE:27:12:EC:17:07:78:C4:25:F7:7E:76:FE:50:D0`.
4. **Build the release bundle** from a machine with the Flutter SDK (not available in this
   sandbox): `flutter build appbundle --release`. Confirm `flutter --version` is recent —
   Flutter 3.44 (current stable as of mid-2026) supports Android API 24–36 out of the box,
   and this project's `build.gradle.kts` already tracks `flutter.compileSdkVersion` /
   `flutter.targetSdkVersion` automatically, so no manual SDK bump is needed as long as your
   local Flutter is up to date (`flutter upgrade` if unsure). Google requires new apps to
   target API 36 (Android 16) by **Aug 31, 2026**, with an extension to Nov 1, 2026 available.
5. **Capture real screenshots** (min 2, max 8) from a device or emulator running the actual
   app — not producible in this sandbox (no Flutter SDK/emulator here). `store_listing/STORE_LISTING.md`
   has the asset checklist; the earlier HTML mockup in this conversation can guide composition.
6. **Create a Play Console developer account** ($25 one-time fee — a real payment, so this
   is yours to make) and enable 2-Step Verification.
7. **Closed testing**: personal Play accounts need 12 testers opted in for 14 consecutive
   days before production access opens up. Start this clock as early as possible — it's
   usually the longest pole in the tent, not the code.
8. **Fill in the Data Safety questionnaire** in Play Console using `docs/PLAY_STORE_DATA_SAFETY.md`
   as your answer key, and the content rating questionnaire (straightforward for this app —
   no violence, no user-generated public content, no gambling; family/social features only
   visible within a private family group).
9. **Push this commit to GitHub** and complete the release signing report for your own
   records: `cd android && ./gradlew signingReport` (needs Android SDK/Gradle locally) to
   double check the fingerprints above match what Gradle sees.

## Not done, and why

- **Cloudinary-hosted media isn't purged by `deleteAccount`** — no Cloudinary API
  credentials are configured server-side. If a deletion request involves someone who
  uploaded vault photos/videos, purge those manually via the Cloudinary dashboard for now;
  see the comment block at the top of `functions/src/account.ts` for exactly what is and
  isn't automated.
- **Shared family content authored by a deleted user isn't deleted or anonymized** when
  other family members remain — documented as an intentional scope limit (same logic as
  leaving a group chat) in both the privacy policy and `account.ts`.

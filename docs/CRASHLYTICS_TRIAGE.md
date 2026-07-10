# Crashlytics triage (operators)

FAM ships with **Firebase Crashlytics** wired in `lib/main.dart`. Collection is **off in debug** and **on in release** so day-to-day development is not noisy.

## Weekly habit (5–10 minutes)

1. Open **Firebase Console → Crashlytics** for project `family-super-app-3bf1c` (or your fork).
2. Sort by **impacted users** or **events** for the last **7 days**.
3. For each cluster:
   - Read the **stack trace** and note which **screen** or **repository** is involved.
   - Reproduce on a **release** or **profile** build if possible (`flutter run --release`).
4. File a fix or add a **breadcrumb** (custom log) before the next release if the cause is unclear.

## What to ignore temporarily

- One-off `OutOfMemory` on very old devices during image pick — track frequency before investing.
- Crashes only on **custom ROMs** with no stack in your code — note and move on unless volume is high.

## What to fix quickly

- Crashes in **auth** or **router** that block sign-in.
- Crashes in **Firestore** listeners that take down the home shell.
- **Top 3** clusters by user count after a beta push.

## After a release

Compare crash-free **sessions** or **users** week over week. If a new spike appears within 48 hours of a rollout, treat it as a **hotfix** candidate.

Run the same checks in [SMOKE_TEST_CHECKLIST.md](SMOKE_TEST_CHECKLIST.md) on the **build you shipped** so Crashlytics spikes map to a known artifact.

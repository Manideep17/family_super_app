# FAM — beta tester guide

Thanks for testing. This is a beta build, so some rough edges are expected.

**Full feature overview for families (non-technical):** see [FOR_FAMILIES_AND_TESTERS.md](FOR_FAMILIES_AND_TESTERS.md) — or the printable [FOR_FAMILIES_AND_TESTERS.pdf](FOR_FAMILIES_AND_TESTERS.pdf).

## Install (Android)

1. Get **`app-release.apk`** from the host (Drive, AirDrop to Android via Files, email attachment, or similar).
2. Open the file on your phone. If Android asks, allow **install from this source** / unknown sources for that app (Files, Chrome, etc.).
3. Complete install and open **FAM**.

### If install is blocked

- Some devices show **Play Protect** scanning; you can tap **Install anyway** if you trust the sender.
- Corporate or school devices may forbid sideloading entirely.

## First-time setup

1. Sign in with **email/password** or **Google**.
2. Either:
   - create a new family, or
   - join using a **6-character invite code** from someone who already created a family.
3. Set your **display name** and optional greeting in profile when prompted.

### If “Continue with Google” fails (error 10 / DEVELOPER_ERROR)

The app owner must register the app’s **SHA-1** fingerprint in Firebase Console (Project settings → Your apps → Android `com.family.superapp`). For the current sideload build, that is usually the **debug keystore** SHA-1 even though the APK is named “release” — ask the host to follow [README.md](../README.md) (Google Sign-In + `signingReport`).

## What to test

- Sign-in and onboarding flow.
- Create/join family by invite code.
- Family chat send and read.
- Task flow: assign, submit, approve/reject.
- Diary: create memory and comments.
- Profile: update name/greeting/avatar.

## Known beta limitations

- Push behavior may vary by device permissions and background restrictions.
- Some advanced automations are still being finalized.
- Media uploads can be disabled for specific beta builds.

## How to report feedback

Please send:

1. What you were doing.
2. What you expected.
3. What happened.
4. Screenshot or screen recording if possible.
5. Your device model and Android version.

This helps us fix issues quickly.

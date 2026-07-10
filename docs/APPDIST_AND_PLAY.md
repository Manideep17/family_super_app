# App Distribution, Play testing, and HTTPS invites

**Android-first** paths to testers. **iOS** distribution (TestFlight) is deferred — skip iOS HTTPS verification until then.

## Firebase App Distribution (recommended for private beta)

1. **Firebase Console** → your project → **App Distribution** → ensure the Android app `com.family.superapp` is registered.
2. **Tester groups** (e.g. `beta-families`):
   - App Distribution → **Testers & Groups** → create a group → add emails.
   - Reuse the group on every upload so you do not retype addresses.
3. **Upload from CI or your machine** using [`scripts/distribute_android_app_distribution.sh`](../scripts/distribute_android_app_distribution.sh):
   - By email: `TESTERS="a@x.com,b@y.com" RELEASE_NOTES="Beta 3" ./scripts/distribute_android_app_distribution.sh`
   - By group: `GROUPS="beta-families" RELEASE_NOTES="Beta 3" ./scripts/distribute_android_app_distribution.sh`
4. Tell testers to use the **email invite** or the **Firebase App Distribution tester app** — avoid sharing expiring CLI download URLs publicly.

## Google Play closed testing (optional)

Use when you want a **Play-signed** artifact and “install from Play” UX for a allowlisted audience.

1. Complete [RELEASE_SIGNING.md](RELEASE_SIGNING.md) (upload keystore, Play App Signing).
2. Create an **AAB**: `flutter build appbundle --release` (same `JAVA_HOME` / `GRADLE_USER_HOME` caveats as [BETA_RELEASE_RUNBOOK.md](BETA_RELEASE_RUNBOOK.md) if builds fail in sandboxes).
3. Play Console → **Testing** → **Closed testing** → create track → upload AAB → add testers by email or Google Group.
4. Register the **release SHA-256** in Firebase for Google Sign-In (see runbook).

Keep **one** primary channel (App Distribution *or* Play closed) per cohort so you know which artifact they run.

## HTTPS invite links (tap-to-join)

Custom scheme `famsuperapp://join/CODE` works immediately. For **`https://your-domain/join/CODE`**:

1. Follow [HTTPS_APP_LINKS.md](HTTPS_APP_LINKS.md) — **`assetlinks.json` for Android** first; **`apple-app-site-association`** only when iOS ships again.
2. Set the same hostname in:
   - `android/app/src/main/res/values/strings.xml` → `invite_https_host`
   - Build flag: `--dart-define=INVITE_HTTPS_HOSTS=join.example.com` (comma-separated for multiple)
   - [`lib/core/config/invite_link_hosts.dart`](../lib/core/config/invite_link_hosts.dart) defaults
3. Rebuild the app after changing the host.

## Quick links

- Tester-facing copy: [FOR_FAMILIES_AND_TESTERS.md](FOR_FAMILIES_AND_TESTERS.md), [BETA_TESTER_GUIDE.md](BETA_TESTER_GUIDE.md)
- Smoke checklist: [SMOKE_TEST_CHECKLIST.md](SMOKE_TEST_CHECKLIST.md)

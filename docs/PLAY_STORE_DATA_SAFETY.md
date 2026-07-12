# Play Console "Data Safety" mapping — FAM

This is a working answer sheet for the Play Console **App content → Data safety** form,
derived from what the code actually does (not a template). Fill the form in using the
"Answer" column for each row. Re-check this doc whenever a feature that touches personal
data changes.

## ✅ Account deletion — now implemented, needs deploy + a live URL

This was a hard blocker (Play requires any app with account creation to also support
deletion, in-app and via web) and is now built:

- **In-app:** `functions/src/account.ts` exports a `deleteAccount` callable Cloud Function.
  It deletes `users/{uid}`, removes the caller from their family's `members` subcollection
  (or, if they're the family's only member, recursively deletes the whole
  `families/{familyId}` tree), then deletes the Firebase Auth user. Wired to a
  **Profile → Danger zone → Delete my account** button
  (`lib/features/profile/presentation/screens/profile_screen.dart`) that requires typing
  "DELETE" to confirm.
- **Web:** `docs/delete-account.html` — a no-backend request page (pre-fills a `mailto:` to
  your support address) for anyone who wants to request deletion without the app installed.

Two things still need to happen before this counts as "live":

1. **Deploy the Cloud Function.** It's written and compiles (`npm run build` in `functions/`
   passes clean) but isn't running anywhere until you deploy — via the
   `.github/workflows/deploy-firebase.yml` GitHub Actions workflow, or `firebase deploy
   --only functions:deleteAccount`. Until deployed, the in-app button will fail with a clear
   error rather than silently doing nothing.
2. **Fill in the real support email and publish the web page.** `docs/delete-account.html`
   and `docs/privacy-policy.html` both have `mandyapp17@gmail.com` placeholders —
   replace with the address you want public (use a personal one, not a work email, since
   this is a personal-account project). Then enable GitHub Pages for this repo (Settings →
   Pages → source: `main` branch, `/docs` folder) to get a real URL like
   `https://Manideep17.github.io/family_super_app/delete-account.html` — use that exact URL
   in both the Data Safety form's "Account deletion" field and the Play Console app listing.

**Known scope limit, documented in `account.ts`'s comments:** if the user is still in a
family with other members, their authored content (tasks, diary posts, chat messages) is
*not* deleted — only their own membership/profile — since that content is shared family data
others rely on (same logic as leaving a group chat). Photos/videos on Cloudinary aren't
auto-purged either, since no Cloudinary API credentials are configured server-side; handle
those manually per request for now.

## Data types collected

| Data type | Collected? | Shared with third parties? | Purpose | Optional or required | Encrypted in transit |
|---|---|---|---|---|---|
| **Name** | Yes (display name, Firebase Auth) | No | Account management, app functionality | Required | Yes |
| **Email address** | Yes (Firebase Auth) | No | Account management, app functionality | Required | Yes |
| **User IDs** | Yes (Firebase UID) | No | Account management, app functionality | Required | Yes |
| **Profile photo** | Yes, only if signing in with Google | No | App functionality (display avatar) | Optional | Yes |
| **Photos** | Yes (family vault uploads) | Yes — Cloudinary, only if `MEDIA_UPLOADS_ENABLED` | App functionality | Optional (user chooses to upload) | Yes |
| **Videos** | Yes (family vault uploads) | Yes — Cloudinary, only if `MEDIA_UPLOADS_ENABLED` | App functionality | Optional | Yes |
| **Other in-app messages** (chat) | Yes (Firestore) | No | App functionality | Required for chat feature | Yes |
| **Other user-generated content** (diary entries, task descriptions, calendar events, poll answers) | Yes (Firestore) | No | App functionality | Required for those features | Yes |
| **App interactions** | Yes (Firebase Analytics — screen views) | No (Google Analytics is Google-owned, not "shared" under Play's definition when used as-is) | Analytics | Required (can't be disabled by user currently — see note) | Yes |
| **Crash logs** | Yes (Firebase Crashlytics) | No | Analytics / app functionality (stability) | Required | Yes |
| **Diagnostics** (device model, OS version) | Yes (Crashlytics) | No | Analytics | Required | Yes |
| **Device or other IDs** | Yes (FCM/OneSignal push token) | Yes — OneSignal, only if configured | App functionality (notifications) | Optional (notifications can be denied at OS level) | Yes |

### Data NOT collected
Precise or approximate location, contacts, phone number, physical address, health/fitness
data, financial info (no payments processed in-app), audio recordings, and browsing history
are **not** collected. Answer "No" / leave unchecked for all of these categories in the form.

### On-device processing note (ML Kit OCR)
Text extraction from vault photos happens **on-device** via Google ML Kit and never leaves
the device as raw image analysis — only the resulting text string is written to Firestore
(same handling as any other user-generated text field above). This is worth calling out in
the form's free-text description field for "Photos", since Play reviewers sometimes ask
about on-device ML.

### Gemini weekly digest note
When enabled, diary/task/event text is sent to Google's Gemini API to generate a summary.
Map this under "Other user-generated content" shared with a service provider (Google), not
as a separate ad-tech category — it's processed to provide the requested feature, not sold
or used for advertising.

## Security practices section

- **Data encrypted in transit:** Yes (all Firebase/Firestore/Cloudinary/Gemini traffic is HTTPS/TLS).
- **Data encrypted at rest:** Yes (Firebase/Firestore/Cloudinary default encryption at rest).
- **Users can request data deletion:** Yes — see the account-deletion section above; fill in
  the actual web URL once you've stood up the deletion request page.
- **Committed to Play Families Policy:** only relevant if you declare the app as
  child-directed. Given FAM is used jointly by parents and kids under a parent-managed
  family and is not primarily targeted at children, declare **general audience / mixed
  audience**, not "designed for children" — this avoids the stricter Families Policy
  requirements (which include e.g. banning most analytics SDKs outright).

## Independent security review / data safety commitments
Not applicable at this size/budget — leave "independent security review" unchecked unless
you've actually had one done.

## Before you submit this form in Play Console
1. Stand up the account-deletion web page and in-app entry point (see gap above) — get the real URL.
2. Host `docs/PRIVACY_POLICY.md` publicly and get that URL too — both this form and the Play
   Console "App content" privacy policy field need it.
3. Re-check whether `MEDIA_UPLOADS_ENABLED` / OneSignal are actually turned on for the build
   you're submitting — the sharing rows above only apply when those flags are on. If they're
   off for launch, mark Cloudinary/OneSignal rows as not applicable.
4. Double check Firebase Analytics collection can, in fact, not be toggled off by the user —
   if there's no opt-out, "required" is the correct answer; if you add a settings toggle
   later, revisit this.

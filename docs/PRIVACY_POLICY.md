# FAM privacy policy

**Last updated:** [fill in date before publishing]

FAM ("the app", "we", "us") is a private family organizer app. This policy explains what
information the app collects, why, and how you can control or delete it.

> **Before you publish this:** replace the bracketed placeholders below (contact email,
> hosting URL, company/developer name), then host this file somewhere with a public URL —
> Play Console requires a live link, not a file in a private repo. GitHub Pages, a single
> page on a personal site, or a free static host all work.

## Who this policy covers

FAM is operated by **[Manideep Biswas — fill in legal name / entity if different]**,
contactable at **[your support email — e.g. manideepbiswas@gmail.com]**.

## Information we collect

FAM only collects information needed to run a private, invite-only family hub. We do not
sell data, and we do not show ads.

### Account information
When you sign in with email/password or Google Sign-In, we collect your **name, email
address**, and — if you sign in with Google — your **Google profile photo**. This is used
to identify you to other members of your family and is stored in Firebase Authentication
and Cloud Firestore.

### Family content
Everything you create inside a family is visible only to members of that family (enforced
by Firestore security rules — see the technical note at the end of this policy):

- **Diary entries** — title, text, mood tag, tagged family members, and any photos/videos you attach.
- **Tasks** — title, description, who assigned/was assigned, due date, and points awarded.
- **Calendar events** — title, description, date/time, and participants.
- **Chat messages** — text sent in the family chat.
- **Vault photos** — photos/videos you upload, any people/event tags you add, and text our
  app automatically detects in the photo (see "On-device photo scanning" below).
- **Polls, predictions, and game results** — whatever you submit while using those features.
- **Gamification data** — points, streaks, and badges, computed from the activity above.

### On-device photo scanning
When you upload a photo to the family vault, the app uses **Google ML Kit**, which runs
**entirely on your device**, to detect any text in the photo (for example, on a report card
or a bill) so you can search for it later. The photo itself is never analyzed by a remote
server for this feature — only the text ML Kit finds is saved to our database, alongside
the photo.

### AI-generated weekly digest (optional feature)
If you use the "weekly digest" feature, a summary of your family's recent diary entries,
completed tasks, and upcoming events is sent to **Google's Gemini API** to generate a short
written recap. This data is processed by Google under Google's own API terms and is not
used by Google to train models on your account's behalf beyond standard API processing.
This feature is off unless explicitly enabled.

### Automatically collected technical information
- **Crash reports** via Firebase Crashlytics (device model, OS version, and the technical
  details of any crash — not your family content).
- **Basic usage analytics** via Firebase Analytics (which screens are opened, not their contents).
- **A push notification token** (Firebase Cloud Messaging and/or OneSignal) so we can deliver
  notifications like task reminders — this token identifies your device/app install, not you personally.

### What we do not collect
We do not access your contacts, precise location, or any data outside the family features
listed above. We do not run advertising, and no third-party advertising SDKs are included
in this app.

## Who we share data with

We use the following third-party service providers to run FAM. Each only receives the data
necessary to provide their service, under their own privacy/security terms:

| Provider | What they process |
|---|---|
| Google Firebase (Auth, Firestore, Storage, Cloud Functions, Crashlytics, Analytics, Cloud Messaging) | Account info, family content, crash/usage data |
| Google Gemini API (via Firebase AI Logic) | Diary/task/event summaries, only if you use the weekly digest feature |
| Cloudinary [if `MEDIA_UPLOADS_ENABLED` is on] | Photos/videos you upload |
| OneSignal [if configured] | Push notification delivery |

We do not sell your data to anyone, and we do not share it for advertising purposes.

## Your choices and rights

- **Access/export:** family content is visible to you at any time inside the app.
- **Delete a photo, task, diary entry, etc.:** available directly in the app (long-press or
  the delete option on that item), where you are the original creator.
- **Delete your account and all associated data:** in the app, go to Profile → Danger zone →
  Delete my account — this deletes immediately. Without the app, use the
  [account deletion request page](https://Manideep17.github.io/family_super_app/delete-account.html)
  or email **[your support email]**; requests are processed within 30 days.
- **Leave a family:** available from the family management screen at any time.

## Children's privacy

FAM is a general family app intended to be used together by people of different ages within
a household, under the account of the adult who set up the family. It is not directed
primarily at children, and we do not knowingly collect personal information directly from a
child without a parent or guardian's involvement in creating and managing the family. If you
believe a child has provided us personal information outside of a parent-managed family,
contact us at **[your support email]** and we will remove it.

## Data retention

We retain family content for as long as your family's account is active. If you delete a
piece of content, it is removed from our active database; some data may persist briefly in
backups before being purged.

## Security

Access to family data is restricted by Firebase security rules to signed-in members of that
specific family. No security measure is perfect, and we can't guarantee absolute security,
but we do not expose family data to the public internet or to other families.

## Changes to this policy

We'll update the "Last updated" date above if this policy changes, and — for material
changes — notify you in-app.

## Contact

Questions about this policy or your data: **[your support email]**.

---

*Technical note (not required reading for users): family data access is enforced
server-side by Firestore and Storage security rules scoped to `families/{familyId}/...`,
requiring the requester to be a member of that specific family — see `firestore.rules` and
`storage.rules` in this project's source code.*

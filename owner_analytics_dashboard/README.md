# Owner Analytics Dashboard (Private)

This is a private owner surface: a **web dashboard** plus an **in-app** screen (`/owner-analytics`) for the same metrics.

In the **mobile app**, allowed users are listed in `lib/core/owner/owner_analytics_emails.dart` (or `--dart-define=OWNER_ANALYTICS_EMAILS=...`). They are routed to **Owner analytics** when they have no family, and can open it from the home drawer when they do.

## What it shows

- **Web dashboard** — **defaults to app-wide totals** (all families). Uncheck “app-wide” in the Status card to see only the family in `users/{uid}.familyId`.
- **In-app owner screen** (`/owner-analytics`) — always **app-wide** totals (same aggregation as the web dashboard with app-wide on).

## What you must deploy (Firestore)

Subcollections are normally readable only by members of that family. For the owner dashboard to load **app-wide** data (or to read another family while your account has no `familyId`), deploy the repo’s **`firestore.rules`** and grant yourself **one** of these:

### Option A — Firestore doc (no Admin SDK)

1. In Firestore, create collection `_internal_rule_config` and document id `app_dashboard_owners`.
2. Add field **`emails`** (type **array**) with your Google sign-in address(es), **lowercase**, e.g. `["manideepbiswas@gmail.com"]`.
3. Clients cannot read this document (`allow read: if false`); rules use it only inside `get()` / `exists()` so your email stays off the public client bundle if you prefer.

**Or** from this repo (Admin SDK — only if you want the script to write/merge the doc; **skip if you already created the document in the console**):

1. **Without gcloud** (recommended if `gcloud` is not installed): Firebase Console → **Project settings** → **Service accounts** → **Generate new private key** (JSON). Then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/full/path/to/your-service-account.json"
cd functions && npm run seed:dashboard-owner
```

2. **With gcloud** (install first, e.g. `brew install --cask google-cloud-sdk`):

```bash
gcloud auth application-default login
cd functions && npm run seed:dashboard-owner
```

That merges `manideepbiswas@gmail.com` by default (override with `DASHBOARD_OWNER_EMAILS=a@x.com,b@y.com`). Script: `functions/scripts/seed_dashboard_owner_allowlist.js`.

### Option B — Custom claim

Set **`appAnalyticsOwner: true`** on your Firebase Auth user (Admin SDK / script). Rules treat that like the internal allowlist for **read** access to all family subcollections. Writes remain member-only.

After either option, redeploy rules: `firebase deploy --only firestore:rules`.

## Security model

- Google sign-in required
- Email allowlist (`allowedEmails`) in `config.js`
- Not linked from the public app marketing site; in-app entry is the drawer (**Owner analytics**) for allowlisted accounts.

Note: `config.js` allowlisting is client-side convenience. **Enforcement** for cross-family reads is in **Firestore rules** (Option A or B above).

## Setup

1. Create `config.js` by copying:

```bash
cp config.sample.js config.js
```

2. Edit `config.js`:
   - Fill Firebase web config
   - Set your owner email in `allowedEmails`

3. Ensure Firebase has a **Web app** created (Project settings -> General -> Your apps -> Web).

4. Run locally:

```bash
cd owner_analytics_dashboard
python3 -m http.server 8080
```

Open: `http://localhost:8080`

## Optional private hosting

- Cloudflare Pages with Google auth in app + allowlist
- Firebase Hosting (same dashboard bundle)

## Data access used

- `users/{uid}` -> `familyId`
- `families/{fid}`
- `families/{fid}/members`
- `families/{fid}/stories`
- `families/{fid}/tasks`
- `families/{fid}/calendar_events`
- `families/{fid}/vault_items`
- `families/{fid}/predictions`
- `families/{fid}/future_predictions`
- `families/{fid}/reels`
- `families/{fid}/creative_submissions`
- `families/{fid}/time_travel_entries`
- `families/{fid}/member_stats`

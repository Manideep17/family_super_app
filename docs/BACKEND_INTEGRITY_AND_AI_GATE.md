# Backend integrity, abuse, and Phase 4 AI

## Push & digest

Weekly champion, optional digest, and related logic live under [`functions/`](../functions/). **Fully automated reminders** still assume Cloud Functions are deployed, FCM tokens are current on `users/{uid}`, and owners who want digests opt in on the family doc (`dailyDigestOptIn`).

If delivery is flaky, triage in order: token freshness → function logs → [`docs/FIREBASE_SETUP.md`](FIREBASE_SETUP.md) and release runbooks.

## Rules vs server validation

Most limits are enforced in **Firestore rules** and client flows. If you see **coin / task / poll abuse** or impossible writes despite rules, escalate to **Callable Cloud Functions** that validate aggregates server-side (sketch below) rather than duplicating logic only in the app.

### Callable stats sketch (only if needed)

- Add a callable that accepts `{ familyId, action, payload }`, looks up the user, runs checks in a transaction, then writes the minimal audit or counter fields.
- Keep payloads small; return explicit error codes for the client.

No callable is wired in-repo until product confirms abuse; this documents the intended escape hatch.

## Phase 4 AI

Anything that looks like **AI highlights, mood analytics, or “best moments” automation** stays behind [`PHASE4_AI_GATE.md`](PHASE4_AI_GATE.md). Treat Phase 4 as a **separate epic** from beta reliability and trust work.

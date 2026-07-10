# Free-tier setup: Cloud Functions (Blaze, capped at $0) + Gemini AI digest (Spark, no billing)

Two separate things unlock two separate parts of this revamp. Neither costs money if you follow the caps below — but they are genuinely separate steps in the Firebase console, so this doc keeps them apart.

## 1. Unblock Cloud Functions (needs Blaze — but $0 if you cap it)

`functions/src/*` (chat triggers, task-approval points, weekly rollups, the memories quiz) cannot deploy on the free Spark plan at all. Cloud Functions require the **Blaze** (pay-as-you-go) plan, which requires a card on file — but Blaze still gives you the same no-cost daily quota Spark has, plus a generous free monthly allotment on top (2M function invocations/month). You will not be charged as long as you stay inside that quota, and you can force that with a budget cap.

Steps:

1. Firebase console → your project → **Upgrade** (bottom-left) → select **Blaze**.
2. Add a payment method (required by Google, not optional — this is the one unavoidable step).
3. Immediately set a budget alert: Google Cloud console → **Billing** → **Budgets & alerts** → create a budget of **$0** (or $1) with alerts at 50%/90%/100%. This won't stop functions from running, but it will email you the instant anything would cost money, so you can react before it's real spend.
4. Optional extra safety: in Cloud Functions settings, you can also cap max instances per function (`maxInstances` in the function definition) to bound worst-case invocation volume.
5. Deploy — pick one:
   - **Option A, GitHub Actions (no local setup):** one-time, create a service account + add it as a repo secret, then click a button. Full steps are in `.github/workflows/deploy-firebase.yml` (top-of-file comment) — it's a `workflow_dispatch` workflow named "Deploy Firebase Backend" in the Actions tab.
   - **Option B, your own machine:**
     ```bash
     npm install -g firebase-tools   # one-time
     firebase login                  # opens a browser, one-time
     cd functions && npm install && cd ..
     firebase deploy --only functions,firestore:rules,firestore:indexes,storage
     ```
     `functions/lib/` and `functions/node_modules/` are build artifacts — already gitignored, nothing to clean up.
6. Rebuild the app with `--dart-define=FUNCTIONS_ENABLED=true` so the client stops using the `FreePushBridge`/`FreeWeeklyRollupService` client-side workarounds and starts trusting the real triggers. `build-apk.yml` already has a checkbox for this on manual runs.

## 2. Enable the Gemini weekly digest (Spark — no billing at all)

The new "Weekly digest" feature (`lib/core/ai/family_digest_service.dart`) uses **Firebase AI Logic** with the **Gemini Developer API** backend (`FirebaseAI.googleAI()`), which is explicitly free and does **not** require Blaze — this is different from the Vertex AI backend, which does. Do not upgrade to Blaze for this step; it's not needed.

Steps:

1. Firebase console → your project → **Build → AI Logic** (left sidebar) → **Get started**.
2. Choose **Gemini Developer API** when prompted for a backend (not Vertex AI).
3. Follow the guided setup — it enables the underlying API and issues the app the access it needs automatically via App Check, no manual API key copy-paste required.
4. Rebuild the app with `--dart-define=AI_DIGEST_ENABLED=true`.
5. Free quota is generous for a family app (roughly 1,500 requests/day on the Flash model as of this writing) but check [ai.google.dev/gemini-api/docs/rate-limits](https://ai.google.dev/gemini-api/docs/rate-limits) since Google adjusts these — if you ever see 429s, the digest screen already fails gracefully with an error message and a retry button.

## Quick reference

| Feature | Needs Blaze? | Console step |
|---|---|---|
| Cloud Functions (chat/task/weekly triggers) | Yes (capped at $0) | Upgrade to Blaze + budget alert |
| Gemini weekly digest | No | AI Logic → Get started → Gemini Developer API |
| ML Kit OCR in vault | No | Nothing — runs on-device, no console step |
| OneSignal push | No | Already free tier, unlimited mobile push |

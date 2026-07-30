# Play Console billing setup

Everything the app and Cloud Functions need on the Play Console side to make
FAM Premium real. Do this after the app is live in at least closed testing —
Play Console won't let you create subscriptions for an app it doesn't
recognize yet.

## 1. Create the subscription product

1. Play Console → your app → **Monetize → Products → Subscriptions**.
2. Create a new subscription with product ID exactly `fam_premium_monthly`
   (must match `AppFlags.premiumMonthlyProductId` in
   `lib/core/config/app_flags.dart` — if you ever change the id there, change
   it here too).
3. Add a base plan (auto-renewing, monthly, whatever price you want to
   charge — you can change price later without changing the product id).
4. Activate the base plan. A subscription with no active base plan won't
   show up in the app's product query.

## 2. Grant the Cloud Functions service account API access

`functions/src/billing.ts` calls the Play Developer (Android Publisher) API
from the `verifySubscriptionPurchase` and `refreshSubscriptions` functions,
authenticated via Application Default Credentials — meaning the *Cloud
Functions runtime service account itself* needs Play Console access, not a
separately downloaded key file.

1. Play Console → **Setup → API access**.
2. Link the Google Cloud project this Firebase project uses (same project
   id as Firebase, since Firebase projects are GCP projects).
3. Under service accounts, find the one named like
   `<project-id>@appspot.gserviceaccount.com` (the default Cloud Functions
   runtime identity) and grant it access.
4. Give it the **"View financial data"** permission at minimum — that's
   what lets `purchases.subscriptionsv2.get` return real data. If Play
   Console asks for app-level permissions too, grant access to this app
   specifically.
5. It can take a few hours for a freshly granted permission to propagate.

## 3. Enable Realtime Developer Notifications (optional, later)

Right now `refreshSubscriptions` polls all active subscriptions once a day
(04:00 IST) as a safety net, and `verifySubscriptionPurchase` verifies on
purchase. That's enough to launch. If churn/refund handling needs to be
faster than "up to 24 hours late," the next step is wiring up Play's
Realtime Developer Notifications (Pub/Sub topic → Cloud Function) instead of
relying on the daily poll — not needed for launch.

## 4. Turn billing on in the app build

Billing stays behind the same flag as other backend-dependent features:

```
flutter build apk --release --dart-define=FUNCTIONS_ENABLED=true --dart-define=AI_DIGEST_ENABLED=true
```

`AppFlags.billingEnabled` just mirrors `FUNCTIONS_ENABLED` — there's no
separate flag, since the paywall is useless without
`verifySubscriptionPurchase` deployed anyway.

## 5. Test with a license tester before going live

Play Console → **Setup → License testing** → add your own Google account as
a tester. License testers can buy real subscription products without being
charged (and can cancel instantly), which is the only way to test the full
purchase → verify → unlock flow before real families see it.

## What's already handled in code

- Entitlement fields (`subscriptionActive`, `subscriptionProductId`,
  `subscriptionExpiresAt`) live on the `Family` document and are populated
  only by `verifySubscriptionPurchase` / `refreshSubscriptions` — the
  Firestore rules' existing allowlist (`hasOnly([...])`) on
  `families/{fid}` updates already blocks clients from writing these fields
  directly (see the comment above that rule).
- Free tier: AI weekly digest and AI quiz are free to use once
  `AI_DIGEST_ENABLED`/backend flags are on; the vault caps free families at
  200 items (`AppFlags.freeVaultItemLimit`) before prompting to upgrade.
- Premium gates: weekly digest screen and vault item cap. The AI quiz is
  **not** gated — it runs entirely on data already in Firestore with no paid
  API call, so there's no cost reason to lock it behind Premium.

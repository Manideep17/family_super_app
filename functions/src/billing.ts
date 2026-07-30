import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { google } from "googleapis";

import { REGION } from "./constants";

// Must match android/app/build.gradle.kts `applicationId`.
const ANDROID_PACKAGE_NAME = "com.family.superapp";

/**
 * Billing — freemium subscription (AI weekly digest, expanded vault
 * storage, AI quiz) gated behind `families/{fid}.subscriptionActive`.
 *
 * Nothing here trusts the client: entitlement is only ever granted after
 * verifying the purchase token server-side against the real Google Play
 * Developer API (Android Publisher API), never from data the app sends
 * about itself.
 *
 * One-time setup this depends on (see docs/BILLING_SETUP.md):
 *   1. Create the `fam_premium_monthly` subscription product in Play
 *      Console (Monetize > Products > Subscriptions).
 *   2. Play Console > Setup > API access > link this Firebase/GCP project,
 *      then grant this function's runtime service account "View financial
 *      data" permission — that's what lets `androidPublisherClient()`
 *      below authenticate with Application Default Credentials (no
 *      separate downloaded key needed).
 */

async function androidPublisherClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  return google.androidpublisher({ version: "v3", auth });
}

/** Returns the subscription's current expiry (ms since epoch) per Play. */
async function fetchExpiryTimeMillis(
  productId: string,
  purchaseToken: string,
): Promise<number> {
  const publisher = await androidPublisherClient();
  const res = await publisher.purchases.subscriptions.get({
    packageName: ANDROID_PACKAGE_NAME,
    subscriptionId: productId,
    token: purchaseToken,
  });
  const expiry = res.data.expiryTimeMillis;
  if (!expiry) {
    throw new Error("Play response had no expiryTimeMillis.");
  }
  return Number(expiry);
}

/**
 * Called by the app right after a purchase (or a restore) completes
 * on-device. Verifies the token with Play, then writes entitlement — this
 * is the *only* path that may set `subscriptionActive: true`.
 */
export const verifySubscriptionPurchase = onCall(
  { region: REGION },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const familyId = String(request.data?.familyId ?? "").trim();
    const productId = String(request.data?.productId ?? "").trim();
    const purchaseToken = String(request.data?.purchaseToken ?? "").trim();
    if (!familyId || !productId || !purchaseToken) {
      throw new HttpsError(
        "invalid-argument",
        "familyId, productId, and purchaseToken are all required.",
      );
    }

    const db = admin.firestore();
    const member = await db
      .collection("families")
      .doc(familyId)
      .collection("members")
      .doc(auth.uid)
      .get();
    if (!member.exists) {
      throw new HttpsError("permission-denied", "Not a member of this family.");
    }

    let expiryTimeMillis: number;
    try {
      expiryTimeMillis = await fetchExpiryTimeMillis(productId, purchaseToken);
    } catch (err) {
      logger.error("verifySubscriptionPurchase: Play verification failed", err);
      throw new HttpsError(
        "internal",
        "Could not verify this purchase with Google Play. Try again shortly.",
      );
    }

    const isActive = expiryTimeMillis > Date.now();
    await db.collection("families").doc(familyId).set(
      {
        subscriptionActive: isActive,
        subscriptionProductId: productId,
        subscriptionExpiresAt: admin.firestore.Timestamp.fromMillis(expiryTimeMillis),
        // Kept so `refreshSubscriptions` (below) can re-check renewal/
        // cancellation status later without the client having to resend it.
        subscriptionPurchaseToken: purchaseToken,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { active: isActive, expiryTimeMillis };
  },
);

/**
 * Daily re-check of every family with a stored purchase token. Play's
 * `purchases.subscriptions.get` always reflects the *current* state of a
 * subscription for a given token (renewed, cancelled, expired, on a grace
 * period, etc.) — re-querying it is how renewals and cancellations get
 * picked up here, since Realtime Developer Notifications (push-based,
 * lower-latency updates) aren't wired up yet. Good enough for launch; if
 * volume grows, add an RTDN Pub/Sub subscriber instead of polling daily.
 */
export const refreshSubscriptions = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "Asia/Kolkata",
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const snap = await db
      .collection("families")
      .where("subscriptionPurchaseToken", "!=", "")
      .get();
    if (snap.empty) {
      logger.info("refreshSubscriptions: no subscriptions to refresh");
      return;
    }
    for (const doc of snap.docs) {
      const data = doc.data();
      const productId = String(data.subscriptionProductId ?? "");
      const token = String(data.subscriptionPurchaseToken ?? "");
      if (!productId || !token) continue;
      try {
        const expiryTimeMillis = await fetchExpiryTimeMillis(productId, token);
        const isActive = expiryTimeMillis > Date.now();
        await doc.ref.set(
          {
            subscriptionActive: isActive,
            subscriptionExpiresAt: admin.firestore.Timestamp.fromMillis(expiryTimeMillis),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      } catch (err) {
        // A single family's stale/revoked token shouldn't stop the rest of
        // the batch from refreshing.
        logger.warn("refreshSubscriptions: failed for family", { familyId: doc.id, err });
      }
    }
    logger.info("refreshSubscriptions: done", { count: snap.size });
  },
);

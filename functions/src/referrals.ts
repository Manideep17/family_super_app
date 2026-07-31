import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION } from "./constants";

/**
 * Referral / growth loop — an existing family shares their `referralCode`;
 * when a brand-new family redeems it, BOTH families get a free premium
 * bonus. Modeled as its own field (`referralBonusExpiresAt`), never the
 * real subscription fields (`subscriptionActive`/`subscriptionExpiresAt`/
 * `subscriptionPurchaseToken`) — those are verified-purchase-only (see
 * billing.ts) and `refreshSubscriptions` recomputes them daily from the
 * real Play Store state for any family with a purchase token. Keeping the
 * referral bonus in a separate field means it can never be silently wiped
 * by that recheck, and `Family.isPremium` (client) just ORs the two
 * conditions together.
 *
 * Same alphabet/length as join codes (see join_codes.ts) — excludes
 * easily-confused characters.
 */
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const BONUS_DAYS = 7;

function randomCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return out;
}

async function assertMember(familyId: string, uid: string): Promise<void> {
  const member = await admin
    .firestore()
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(uid)
    .get();
  if (!member.exists) {
    throw new HttpsError("permission-denied", "Not a member of this family.");
  }
}

/**
 * Idempotent: if the family already has a referral code, returns the
 * existing one instead of minting a new one every time the "Invite &
 * earn" screen opens.
 */
export const allocateReferralCode = onCall(
  { region: REGION },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const familyId = String(request.data?.familyId ?? "").trim();
    if (!familyId) {
      throw new HttpsError("invalid-argument", "familyId is required.");
    }
    await assertMember(familyId, auth.uid);

    const db = admin.firestore();
    const familyRef = db.collection("families").doc(familyId);
    const existing = (await familyRef.get()).data()?.referralCode;
    if (typeof existing === "string" && existing.length === CODE_LENGTH) {
      return { referralCode: existing };
    }

    for (let attempt = 0; attempt < 8; attempt++) {
      const code = randomCode();
      const clash = await db
        .collection("families")
        .where("referralCode", "==", code)
        .limit(1)
        .get();
      if (clash.empty) {
        await familyRef.set(
          {
            referralCode: code,
            referralCount: admin.firestore.FieldValue.increment(0),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return { referralCode: code };
      }
    }
    throw new HttpsError(
      "resource-exhausted",
      "Could not allocate a referral code, try again.",
    );
  },
);

/**
 * Redeems someone else's referral code for the caller's own family.
 * One-time per family (guarded by `referredByFamilyId`) and no
 * self-referral. Grants both families a `referralBonusExpiresAt` bump.
 */
export const redeemReferralCode = onCall(
  { region: REGION },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const familyId = String(request.data?.familyId ?? "").trim();
    const code = String(request.data?.referralCode ?? "").trim().toUpperCase();
    if (!familyId || code.length !== CODE_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "familyId and a 6-character referralCode are required.",
      );
    }
    await assertMember(familyId, auth.uid);

    const db = admin.firestore();
    const redeemerRef = db.collection("families").doc(familyId);

    const matches = await db
      .collection("families")
      .where("referralCode", "==", code)
      .limit(1)
      .get();
    if (matches.empty) {
      throw new HttpsError("not-found", "No family found for that referral code.");
    }
    const referrerRef = matches.docs[0].ref;
    if (referrerRef.id === familyId) {
      throw new HttpsError("invalid-argument", "You can't redeem your own code.");
    }

    const bonusUntil = admin.firestore.Timestamp.fromMillis(
      Date.now() + BONUS_DAYS * 24 * 60 * 60 * 1000,
    );

    const result = await db.runTransaction(async (tx) => {
      const redeemerSnap = await tx.get(redeemerRef);
      const referrerSnap = await tx.get(referrerRef);
      if (!referrerSnap.exists) {
        throw new HttpsError("not-found", "That referral code's family no longer exists.");
      }
      const already = redeemerSnap.data()?.referredByFamilyId;
      if (typeof already === "string" && already.length > 0) {
        throw new HttpsError(
          "already-exists",
          "This family has already redeemed a referral code.",
        );
      }

      tx.set(
        redeemerRef,
        {
          referredByFamilyId: referrerRef.id,
          referralBonusExpiresAt: bonusUntil,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Extend from whichever is later: the referrer's existing bonus
      // expiry (if still active) or now — so redeeming several friends'
      // signups stacks instead of resetting to a flat 7 days each time.
      const referrerData = referrerSnap.data() ?? {};
      const currentExpiryMs =
        referrerData.referralBonusExpiresAt instanceof admin.firestore.Timestamp
          ? referrerData.referralBonusExpiresAt.toMillis()
          : 0;
      const extendFromMs = Math.max(currentExpiryMs, Date.now());
      const referrerBonusUntil = admin.firestore.Timestamp.fromMillis(
        extendFromMs + BONUS_DAYS * 24 * 60 * 60 * 1000,
      );
      tx.set(
        referrerRef,
        {
          referralBonusExpiresAt: referrerBonusUntil,
          referralCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { bonusDays: BONUS_DAYS };
    });

    return { ok: true, ...result };
  },
);

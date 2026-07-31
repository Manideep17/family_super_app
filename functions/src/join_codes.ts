import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION } from "./constants";

// Same alphabet/length as the client used to generate locally (excludes
// easily-confused characters: no I, O, 0, 1).
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;

function randomCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return out;
}

/**
 * Looks up a family by its 6-character invite code, using the admin SDK.
 *
 * This exists specifically so `families/{fid}` can lock down `list`
 * (collection queries) in firestore.rules — a `joinCode` is a short,
 * human-typed string (32^6 ≈ 1.07B combinations), which is exactly the
 * kind of value that must never be searchable via a client-side
 * `where('joinCode', '==', ...)` query, since that would let anyone
 * enumerate/brute-force real join codes. Direct `get()` of a family by its
 * real (random, ~20-char) document id is still allowed for any signed-in
 * user — that's a much narrower, effectively unguessable exposure, and is
 * still needed for the join transaction's own existence check before the
 * new member doc exists.
 */
export const resolveJoinCode = onCall({ region: REGION }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const raw = String(request.data?.joinCode ?? "").trim().toUpperCase();
  if (raw.length !== CODE_LENGTH) {
    throw new HttpsError("invalid-argument", "Invite codes are 6 characters.");
  }
  const snap = await admin
    .firestore()
    .collection("families")
    .where("joinCode", "==", raw)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new HttpsError("not-found", "No family found for that code.");
  }
  const doc = snap.docs[0];
  return { familyId: doc.id, name: String(doc.data().name ?? "Family") };
});

/**
 * Allocates a fresh, collision-checked 6-character join code for a
 * brand-new family. Needs the admin SDK for the same reason as
 * `resolveJoinCode` above — checking uniqueness means querying `joinCode`
 * across every family, which client code can no longer do directly once
 * `list` is locked down.
 */
export const allocateJoinCode = onCall({ region: REGION }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const db = admin.firestore();
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = randomCode();
    const existing = await db
      .collection("families")
      .where("joinCode", "==", code)
      .limit(1)
      .get();
    if (existing.empty) {
      return { joinCode: code };
    }
  }
  throw new HttpsError(
    "resource-exhausted",
    "Could not allocate a join code, try again.",
  );
});

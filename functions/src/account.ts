import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION } from "./constants";

/**
 * Account deletion — required by Google Play's Account Deletion policy for
 * any app that supports account creation (see docs/PLAY_STORE_DATA_SAFETY.md).
 *
 * Scope of what this deletes:
 *   - The caller's `users/{uid}` pointer doc.
 *   - The caller's `families/{fid}/members/{uid}` doc.
 *   - If the caller is the *only* member of their family, the entire
 *     `families/{fid}` document tree (every subcollection: tasks, stories,
 *     chat, vault, calendar, polls, predictions, gamification stats, etc.)
 *     via `recursiveDelete`, since nobody else has a stake in that data.
 *   - The Firebase Auth user record itself.
 *
 * What this deliberately does NOT delete: content the caller authored
 * inside a family that still has other members (their tasks, diary
 * entries, chat messages). That content is shared family data other
 * members rely on, same as a group chat when one participant leaves — the
 * privacy policy documents this. If a fuller "scrub my authored content"
 * pass is ever wanted, extend `wipeSoleMemberFamily` / add an
 * `anonymizeAuthoredContent` step here.
 *
 * What this cannot delete on its own: any photo/video the user uploaded
 * that lives on Cloudinary (see MEDIA_UPLOADS_ENABLED) — this project has
 * no Cloudinary API credentials wired server-side. Handle those manually
 * per the request, or add a Cloudinary destroy() call here once an API
 * secret is configured.
 */
export const deleteAccount = onCall({ region: REGION }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = auth.uid;
  const db = admin.firestore();

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const familyId = String(userSnap.data()?.familyId ?? "").trim();

  let familyWiped = false;

  if (familyId) {
    const familyRef = db.collection("families").doc(familyId);
    const membersRef = familyRef.collection("members");
    const memberRef = membersRef.doc(uid);

    const membersSnap = await membersRef.orderBy("joinedAt", "asc").get();
    const otherMembers = membersSnap.docs.filter((d) => d.id !== uid);

    if (otherMembers.length === 0) {
      // Sole member — safe to remove the whole family tree.
      await db.recursiveDelete(familyRef);
      familyWiped = true;
    } else {
      // Other members still depend on shared family data — only remove
      // this person's own membership record. But if the departing member
      // is the family owner, `ownerUid` would keep pointing at a uid that
      // no longer exists — every owner-only action in firestore.rules
      // (pinned announcements, digest toggle, ownership transfer itself)
      // checks against that uid, so once it's gone nothing could ever
      // satisfy that check again and the family would be permanently
      // stuck. Reassign ownership to the longest-standing remaining member
      // first, in the same spirit as the rules' own
      // `priorFamilyOwnerId()`/`familyDocOwnerUid()` fallback logic
      // (`ownerUid` if set, else `createdBy`).
      const familySnap = await familyRef.get();
      const familyData = familySnap.data() ?? {};
      const currentOwnerUid =
        typeof familyData.ownerUid === "string" && familyData.ownerUid.length > 0
          ? familyData.ownerUid
          : String(familyData.createdBy ?? "");

      if (currentOwnerUid === uid) {
        const successor = otherMembers[0];
        await familyRef.set(
          {
            ownerUid: successor.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      await memberRef.delete().catch(() => undefined);
    }
  }

  await userRef.delete().catch(() => undefined);
  await admin.auth().deleteUser(uid);

  return { ok: true, familyId: familyId || null, familyWiped };
});

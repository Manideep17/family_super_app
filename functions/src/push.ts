import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

/**
 * Loads FCM tokens for members inside `families/{familyId}/members`,
 * optionally excluding one uid.
 * Stale tokens are pruned best-effort when send fails.
 */
export async function loadFamilyTokens(
  familyId: string,
  excludeUid?: string,
): Promise<{ tokens: string[]; uidByToken: Record<string, string> }> {
  const memberSnap = await admin
    .firestore()
    .collection("families")
    .doc(familyId)
    .collection("members")
    .get();
  const uids = memberSnap.docs.map((d) => d.id).filter((id) => id !== excludeUid);
  if (uids.length === 0) return { tokens: [], uidByToken: {} };

  const tokens: string[] = [];
  const uidByToken: Record<string, string> = {};
  const users = await Promise.all(
    uids.map((uid) => admin.firestore().collection("users").doc(uid).get()),
  );
  users.forEach((doc) => {
    if (!doc.exists) return;
    const token = doc.get("fcmToken");
    if (typeof token === "string" && token.length > 0) {
      tokens.push(token);
      uidByToken[token] = doc.id;
    }
  });
  return { tokens, uidByToken };
}

export interface PushPayload {
  title: string;
  body: string;
  /**
   * Free-form data sent to the client. The Flutter side reads
   * `route` to decide where to navigate when the user taps the
   * notification.
   */
  data?: Record<string, string>;
}

export async function sendToFamily(
  familyId: string,
  payload: PushPayload,
  excludeUid?: string,
): Promise<void> {
  const { tokens, uidByToken } = await loadFamilyTokens(familyId, excludeUid);
  if (tokens.length === 0) {
    logger.info("sendToFamily: no tokens", { familyId, excludeUid });
    return;
  }

  const messaging = admin.messaging();
  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data ?? {},
    android: {
      priority: "high",
      notification: {
        channelId: "family_default",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: { sound: "default", badge: 1 },
      },
    },
  });

  const stale: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code ?? "";
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        stale.push(tokens[i]);
      } else {
        logger.warn("FCM send error", {
          code,
          message: r.error?.message,
          familyId,
          uid: uidByToken[tokens[i]],
        });
      }
    }
  });

  if (stale.length > 0) {
    const db = admin.firestore();
    await Promise.all(
      stale.map(async (t) => {
        const uid = uidByToken[t];
        if (!uid) return;
        await db
          .collection("users")
          .doc(uid)
          .update({
            fcmToken: admin.firestore.FieldValue.delete(),
          })
          .catch(() => undefined);
      }),
    );
    logger.info("Pruned stale FCM tokens", { familyId, count: stale.length });
  }
}

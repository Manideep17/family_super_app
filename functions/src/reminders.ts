import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

import { REGION } from "./constants";
import { sendToFamily } from "./push";

/**
 * Sends a gentle daily nudge to families that opted in (`dailyDigestOptIn`).
 * Owners toggle this from **My family** in the app.
 */
export const scheduledFamilyDigest = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "Asia/Kolkata",
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const snap = await db
      .collection("families")
      .where("dailyDigestOptIn", "==", true)
      .get();
    if (snap.empty) {
      logger.info("scheduledFamilyDigest: no opted-in families");
      return;
    }
    for (const doc of snap.docs) {
      const familyId = doc.id;
      try {
        await sendToFamily(familyId, {
          title: "Good morning from FAM",
          body: "Open the app to catch up with your family.",
          data: { route: "/home" },
        });
      } catch (e) {
        logger.warn("scheduledFamilyDigest: send failed", { familyId, e });
      }
    }
    logger.info("scheduledFamilyDigest: done", { count: snap.size });
  },
);

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { REGION } from "./constants";

/**
 * Logs unusually large single-write point jumps. Client rules still allow
 * self-writes; use this signal to investigate abuse before tightening rules
 * or adding callable validation.
 */
export const auditMemberStatsWrite = onDocumentWritten(
  {
    document: "families/{fid}/member_stats/{uid}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;
    const pb = Number(before?.points ?? 0);
    const pa = Number(after.points ?? 0);
    const delta = pa - pb;
    if (delta > 800) {
      logger.warn("Large points delta on member_stats", {
        fid: event.params.fid,
        uid: event.params.uid,
        delta,
      });
    }
    const cb = Number(before?.famCoins ?? 0);
    const ca = Number(after.famCoins ?? 0);
    const coinDelta = ca - cb;
    if (coinDelta > 300) {
      logger.warn("Large famCoins increase on member_stats", {
        fid: event.params.fid,
        uid: event.params.uid,
        coinDelta,
      });
    }
    const sb = Number(before?.storiesCreated ?? 0);
    const sa = Number(after.storiesCreated ?? 0);
    if (sa - sb > 15) {
      logger.warn("Large storiesCreated jump on member_stats", {
        fid: event.params.fid,
        uid: event.params.uid,
        delta: sa - sb,
      });
    }
    const gb = Number(before?.gamesWon ?? 0);
    const ga = Number(after.gamesWon ?? 0);
    if (ga - gb > 15) {
      logger.warn("Large gamesWon jump on member_stats", {
        fid: event.params.fid,
        uid: event.params.uid,
        delta: ga - gb,
      });
    }
  },
);

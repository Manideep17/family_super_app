import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

import { REGION } from "./constants";
import { sendToFamily } from "./push";

function weekId(d: Date): string {
  const target = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNr = (target.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - dayNr + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const firstDayNr = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDayNr + 3);
  const week =
    1 +
    Math.round(
      (target.getTime() - firstThursday.getTime()) /
        (7 * 24 * 3600 * 1000),
    );
  const yyyy = target.getUTCFullYear();
  const ww = String(week).padStart(2, "0");
  return `${yyyy}-W${ww}`;
}

export const weeklyChampionRollup = onSchedule(
  {
    schedule: "every monday 00:05",
    timeZone: "Asia/Kolkata",
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const families = await db.collection("families").get();
    for (const familyDoc of families.docs) {
      const familyId = familyDoc.id;
      const snap = await familyDoc.ref
        .collection("member_stats")
        .orderBy("points", "desc")
        .limit(1)
        .get();
      if (snap.empty) continue;

      const top = snap.docs[0];
      const data = top.data();
      const wid = weekId(new Date());
      const champion = {
        weekId: wid,
        championUid: top.id,
        championName: data.displayName ?? data.email ?? "Family",
        championPoints: Number(data.points ?? 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await familyDoc.ref
        .collection("gamification")
        .doc("weekly_champion")
        .set(champion, { merge: true });

      await sendToFamily(familyId, {
        title: "Family champion of the week 🏆",
        body: `${champion.championName} — ${champion.championPoints} pts`,
        data: { route: "/home", tab: "leaderboard" },
      });
    }
  },
);

export const bestMomentsRollup = onSchedule(
  {
    schedule: "every sunday 23:00",
    timeZone: "Asia/Kolkata",
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const families = await db.collection("families").get();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 3600 * 1000),
    );

    for (const familyDoc of families.docs) {
      const familyId = familyDoc.id;
      const snap = await familyDoc.ref
        .collection("stories")
        .where("createdAt", ">=", cutoff)
        .get();
      if (snap.empty) {
        logger.info("bestMomentsRollup: no stories", { familyId });
        continue;
      }

      const ranked = snap.docs
        .map((doc) => {
          const d = doc.data();
          const reactions = d.reactions ?? {};
          const reactionCount = Object.keys(reactions).length;
          const commentCount = Number(d.commentCount ?? 0);
          const score = reactionCount * 2 + commentCount;
          const images = Array.isArray(d.imageUrls) ? d.imageUrls : [];
          return {
            id: doc.id,
            title: d.title ?? "",
            body: d.body ?? "",
            mood: d.mood ?? "happy",
            authorName: d.authorName ?? "",
            reactions: reactionCount,
            commentCount,
            firstImageUrl: images.length > 0 ? String(images[0]) : null,
            createdAt: d.createdAt ?? null,
            score,
          };
        })
        .sort((a, b) => b.score - a.score)
        .slice(0, 3);

      const wid = weekId(new Date());
      await familyDoc.ref.collection("best_moments").doc(wid).set(
        {
          weekId: wid,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          stories: ranked.map(({ score: _score, ...rest }) => rest),
        },
        { merge: true },
      );

      if (ranked.length > 0) {
        await sendToFamily(familyId, {
          title: "Best moments of the week ✨",
          body: `${ranked.length} memor${ranked.length === 1 ? "y" : "ies"} from your family`,
          data: { route: "/home", tab: "insights" },
        });
      }
    }
  },
);

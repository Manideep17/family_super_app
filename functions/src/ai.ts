import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION } from "./constants";

interface QuizQuestion {
  prompt: string;
  options: string[];
  answerIndex: number;
  storyId: string;
}

export const aiQuizFromMemories = onCall(
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

    const snap = await db
      .collection("families")
      .doc(familyId)
      .collection("stories")
      .orderBy("createdAt", "desc")
      .limit(40)
      .get();

    const stories = snap.docs
      .map((doc) => {
        const d = doc.data();
        return {
          id: doc.id,
          authorName: String(d.authorName ?? "Family"),
          body: String(d.body ?? d.title ?? ""),
        };
      })
      .filter((s) => s.body.trim().length > 12);

    if (stories.length < 5) {
      throw new HttpsError(
        "failed-precondition",
        "Need at least 5 diary entries before we can build a quiz.",
      );
    }

    const membersSnap = await db
      .collection("families")
      .doc(familyId)
      .collection("members")
      .get();
    const namePool = Array.from(
      new Set(
        membersSnap.docs
          .map((d) => String(d.get("displayName") ?? ""))
          .filter((n) => n.length > 0),
      ),
    );
    if (namePool.length < 2) {
      throw new HttpsError(
        "failed-precondition",
        "Need at least 2 family members for a quiz.",
      );
    }

    const picked: QuizQuestion[] = [];
    const seen = new Set<string>();
    while (picked.length < 5 && seen.size < stories.length) {
      const i = Math.floor(Math.random() * stories.length);
      const s = stories[i];
      if (seen.has(s.id)) continue;
      seen.add(s.id);
      const correct = s.authorName;
      const distractors = namePool.filter((n) => n !== correct);
      shuffle(distractors);
      const options = [correct, ...distractors.slice(0, 3)];
      while (options.length < 4 && namePool.length > 0) {
        options.push(namePool[Math.floor(Math.random() * namePool.length)]);
      }
      shuffle(options);
      const snippet = s.body.length > 160 ? `${s.body.slice(0, 157)}...` : s.body;
      picked.push({
        prompt: `Who wrote this? "${snippet}"`,
        options,
        answerIndex: options.indexOf(correct),
        storyId: s.id,
      });
    }

    if (picked.length < 5) {
      throw new HttpsError(
        "internal",
        "Couldn't assemble enough quiz questions; try again later.",
      );
    }

    const quizRef = db
      .collection("families")
      .doc(familyId)
      .collection("ai_quizzes")
      .doc();
    await quizRef.set({
      title: "Memories Quiz",
      questions: picked,
      createdBy: auth.uid,
      createdByName: auth.token.name ?? auth.token.email ?? "Family",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: "heuristic-v1",
    });

    return { quizId: quizRef.id, questionCount: picked.length };
  },
);

function shuffle<T>(arr: T[]): void {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
}

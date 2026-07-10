import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { REGION } from "./constants";

type DemoMember = {
  uid: string;
  email: string;
  displayName: string;
  greeting: string;
};

function pick(members: DemoMember[], index: number): DemoMember {
  return members[index % members.length];
}

function daysAgo(days: number, hour = 10): Date {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(hour, 0, 0, 0);
  return d;
}

async function seedDemoDataForFamily(familyId: string): Promise<void> {
  const db = admin.firestore();
  const familyRef = db.collection("families").doc(familyId);
  const familySnap = await familyRef.get();
  if (!familySnap.exists) return;
  const family = familySnap.data() ?? {};
  const demoMode = family.demoMode === true;
  const seededAt = family.demoSeededAt;
  const memberCount = Number(family.memberCount ?? 0);
  if (!demoMode || seededAt) return;
  if (memberCount < 2) {
    logger.info("demo seed skipped: waiting for >=2 members", { familyId, memberCount });
    return;
  }

  const lockRef = familyRef.collection("system").doc("demo_seed_lock");
  try {
    await lockRef.create({
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "running",
    });
  } catch {
    logger.info("demo seed lock already exists", { familyId });
    return;
  }

  try {
    const freshFamily = await familyRef.get();
    const fresh = freshFamily.data() ?? {};
    if (fresh.demoMode !== true || fresh.demoSeededAt) {
      return;
    }

    const memberSnap = await familyRef
      .collection("members")
      .orderBy("joinedAt", "asc")
      .get();
    const members: DemoMember[] = memberSnap.docs
      .map((doc) => {
        const d = doc.data();
        const email = String(d.email ?? "").trim().toLowerCase();
        const displayName = String(d.displayName ?? "").trim();
        return {
          uid: doc.id,
          email,
          displayName: displayName.length > 0 ? displayName : "Member",
          greeting: String(d.greeting ?? "").trim(),
        };
      })
      .filter((m) => m.email.length > 0);

    if (members.length < 2) {
      logger.info("demo seed skipped: members unavailable after lock", { familyId });
      return;
    }

    const emails = members.map((m) => m.email);

    // Keep users/{uid} aligned with demo names/greetings.
    for (const m of members) {
      await db.collection("users").doc(m.uid).set(
        {
          email: m.email,
          familyId,
          displayName: m.displayName,
          greeting: m.greeting,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    const chatRef = familyRef.collection("chats").doc("main");
    const membersMap: Record<string, unknown> = {};
    const readThrough: Record<string, unknown> = {};
    for (const m of members) {
      membersMap[m.uid] = {
        email: m.email,
        name: m.displayName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      readThrough[m.uid] = admin.firestore.Timestamp.fromDate(daysAgo(0, 9));
    }
    await chatRef.set(
      {
        members: membersMap,
        readThrough,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const chatMessages = [
      { d: 2, text: "Welcome to this beta family space." },
      { d: 2, text: "Please test chat, tasks, diary, and profile updates." },
      { d: 1, text: "I just added a sample memory and a task." },
      { d: 0, text: "Can someone submit one sample task?" },
      { d: 0, text: "Done. Looks good from my device too." },
    ];
    for (let i = 0; i < chatMessages.length; i += 1) {
      const msg = chatMessages[i];
      const author = pick(members, i);
      await chatRef.collection("messages").add({
        text: msg.text,
        authorUid: author.uid,
        authorName: author.displayName,
        createdAt: admin.firestore.Timestamp.fromDate(daysAgo(msg.d, 10 + i)),
        type: "text",
        reactions: {},
        demoSeed: true,
      });
    }

    const storySeeds = [
      {
        title: "Weekend breakfast",
        body: "We planned the week together and shared updates.",
        mood: "calm",
        d: 3,
      },
      {
        title: "Evening walk",
        body: "We discussed school, work, and clicked a few photos.",
        mood: "happy",
        d: 1,
      },
      {
        title: "Tiny celebration",
        body: "We finished tasks and celebrated with dessert.",
        mood: "proud",
        d: 0,
      },
    ];
    for (let i = 0; i < storySeeds.length; i += 1) {
      const s = storySeeds[i];
      const author = pick(members, i);
      const tagged = emails.filter((e) => e !== author.email).slice(0, 2);
      const storyRef = await familyRef.collection("stories").add({
        title: s.title,
        body: s.body,
        mood: s.mood,
        authorUid: author.uid,
        authorName: author.displayName,
        authorEmail: author.email,
        taggedEmails: tagged,
        imageUrls: [],
        videoUrls: [],
        reactions: {},
        commentCount: 1,
        createdAt: admin.firestore.Timestamp.fromDate(daysAgo(s.d, 18 - i)),
        demoSeed: true,
      });
      const commenter = pick(members, i + 1);
      await storyRef.collection("comments").add({
        text: "Great memory. Works nicely in beta.",
        authorUid: commenter.uid,
        authorName: commenter.displayName,
        createdAt: admin.firestore.Timestamp.fromDate(daysAgo(s.d, 19 - i)),
        demoSeed: true,
      });
    }

    const taskSeeds = [
      { title: "Test chat flow", status: "pending", d: 0, dueOffset: 1 },
      { title: "Submit a memory task", status: "submitted", d: 1, dueOffset: 2 },
      { title: "Verify profile greeting", status: "approved", d: 2, dueOffset: 0 },
    ];
    for (let i = 0; i < taskSeeds.length; i += 1) {
      const t = taskSeeds[i];
      const assigner = pick(members, i);
      const assignee = pick(members, i + 1);
      const created = daysAgo(t.d, 11 + i);
      const due = new Date(created);
      due.setDate(due.getDate() + t.dueOffset + 1);
      const payload: Record<string, unknown> = {
        title: t.title,
        description: "Sample beta task seeded automatically.",
        assignerUid: assigner.uid,
        assignerEmail: assigner.email,
        assignerName: assigner.displayName,
        assigneeUid: assignee.uid,
        assigneeEmail: assignee.email,
        assigneeName: assignee.displayName,
        participantEmails: [assigner.email, assignee.email].sort(),
        dueAt: admin.firestore.Timestamp.fromDate(due),
        rewardPoints: 15 + i * 5,
        status: t.status,
        createdAt: admin.firestore.Timestamp.fromDate(created),
        demoSeed: true,
      };
      if (t.status === "submitted" || t.status === "approved") {
        payload.submittedAt = admin.firestore.FieldValue.serverTimestamp();
        payload.submittedNote = "Completed in beta check.";
      }
      if (t.status === "approved") {
        payload.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
      }
      await familyRef.collection("tasks").add(payload);
    }

    const eventSeeds = [
      { title: "Family beta check-in", days: 1, allDay: false, type: "reminder" },
      { title: "Weekend plan", days: 3, allDay: true, type: "other" },
    ];
    for (let i = 0; i < eventSeeds.length; i += 1) {
      const e = eventSeeds[i];
      const creator = pick(members, i);
      const start = new Date();
      start.setDate(start.getDate() + e.days);
      start.setHours(e.allDay ? 9 : 19, 0, 0, 0);
      await familyRef.collection("calendar_events").add({
        title: e.title,
        description: "Seeded event for beta testing.",
        startAt: admin.firestore.Timestamp.fromDate(start),
        endAt: null,
        allDay: e.allDay,
        eventType: e.type,
        creatorUid: creator.uid,
        creatorName: creator.displayName,
        creatorEmail: creator.email,
        participantEmails: emails,
        demoSeed: true,
      });
    }

    for (let i = 0; i < members.length; i += 1) {
      const m = members[i];
      await familyRef.collection("member_stats").doc(m.uid).set(
        {
          email: m.email,
          displayName: m.displayName,
          points: 40 + i * 15,
          storiesCreated: 1 + (i % 2),
          gamesWon: i % 2,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    await familyRef.set(
      {
        demoSeededAt: admin.firestore.FieldValue.serverTimestamp(),
        demoSeedVersion: 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await lockRef.set(
      {
        status: "done",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    logger.info("demo seed completed", { familyId, members: members.length });
  } catch (err) {
    logger.error("demo seed failed", { familyId, err });
    await lockRef.set(
      {
        status: "failed",
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

export const onFamilyDemoModeWrite = onDocumentWritten(
  { document: "families/{familyId}", region: REGION },
  async (event) => {
    const after = event.data?.after.data();
    if (!after) return;
    if (after.demoMode !== true) return;
    await seedDemoDataForFamily(event.params.familyId);
  },
);

export const onFamilyMemberJoinedDemoSeed = onDocumentCreated(
  { document: "families/{familyId}/members/{uid}", region: REGION },
  async (event) => {
    await seedDemoDataForFamily(event.params.familyId);
  },
);

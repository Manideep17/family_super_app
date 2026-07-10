import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { REGION } from "./constants";

async function uidForEmail(
  familyId: string,
  email: string,
): Promise<string | null> {
  const snap = await admin
    .firestore()
    .collection("families")
    .doc(familyId)
    .collection("members")
    .where("email", "==", email.toLowerCase())
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

async function notifyUid(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const token = userDoc.get("fcmToken");
  if (typeof token !== "string" || token.length === 0) {
    logger.info("notifyUid: no token", { uid });
    return;
  }

  await admin.messaging().send({
    token,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: { channelId: "family_default", sound: "default" },
    },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  });
}

export const onTaskCreated = onDocumentCreated(
  { document: "families/{familyId}/tasks/{taskId}", region: REGION },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const familyId = event.params.familyId;
    const assigneeEmail: string = data.assigneeEmail ?? "";
    const title: string = data.title ?? "New task";
    const assignerName: string = data.assignerName ?? "A member";
    if (!assigneeEmail) return;

    const uid = await uidForEmail(familyId, assigneeEmail);
    if (!uid) return;

    await notifyUid(
      uid,
      `${assignerName} assigned you a task`,
      title,
      {
        route: "/home",
        tab: "tasks",
        taskId: event.params.taskId,
      },
    );
  },
);

export const onTaskUpdated = onDocumentUpdated(
  { document: "families/{familyId}/tasks/{taskId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    const familyId = event.params.familyId;
    const status: string = after.status ?? "";
    const title: string = after.title ?? "Task";
    const assigneeName: string = after.assigneeName ?? "Someone";
    const assignerEmail: string = after.assignerEmail ?? "";
    const assigneeEmail: string = after.assigneeEmail ?? "";

    if (status === "submitted" && assignerEmail) {
      const uid = await uidForEmail(familyId, assignerEmail);
      if (uid) {
        await notifyUid(
          uid,
          `${assigneeName} submitted a task`,
          `Tap to approve or reject: ${title}`,
          { route: "/home", tab: "tasks", taskId: event.params.taskId },
        );
      }
    } else if (status === "approved" && assigneeEmail) {
      const uid = await uidForEmail(familyId, assigneeEmail);
      if (uid) {
        const points: number = Number(after.rewardPoints ?? 0);
        await notifyUid(
          uid,
          "Task approved 🎉",
          points > 0 ? `${title} — you earned ${points} points` : title,
          { route: "/home", tab: "tasks", taskId: event.params.taskId },
        );
      }
    } else if (status === "rejected" && assigneeEmail) {
      const uid = await uidForEmail(familyId, assigneeEmail);
      if (uid) {
        const reason: string = after.rejectedReason ?? "Try again";
        await notifyUid(
          uid,
          "Task needs another try",
          `${title}: ${reason}`,
          { route: "/home", tab: "tasks", taskId: event.params.taskId },
        );
      }
    }
  },
);

export const onTaskApprovedAwardPoints = onDocumentUpdated(
  { document: "families/{familyId}/tasks/{taskId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "approved") return;

    const familyId = event.params.familyId;
    const assigneeUid: string = after.assigneeUid ?? "";
    const rewardPoints = Number(after.rewardPoints ?? 0);
    if (!assigneeUid || rewardPoints <= 0) return;

    const taskRef = admin
      .firestore()
      .doc(`families/${familyId}/tasks/${event.params.taskId}`);
    const statsRef = admin
      .firestore()
      .collection("families")
      .doc(familyId)
      .collection("member_stats")
      .doc(assigneeUid);

    const fresh = await taskRef.get();
    if (fresh.get("serverPointsAwarded") === true) return;

    await admin.firestore().runTransaction(async (tx) => {
      const taskSnap = await tx.get(taskRef);
      if (taskSnap.get("serverPointsAwarded") === true) return;
      tx.set(
        statsRef,
        {
          email: (after.assigneeEmail ?? "").toLowerCase(),
          displayName: after.assigneeName ?? "",
          points: admin.firestore.FieldValue.increment(rewardPoints),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.update(taskRef, { serverPointsAwarded: true });
    });
  },
);

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";

// Resolve the repo's real firestore.rules regardless of the cwd this script
// is invoked from (run via `npm run test:rules` from functions/, which
// invokes `firebase emulators:exec` -- firebase-tools itself walks up to
// find firebase.json/.firebaserc, but this file read is ours to control).
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RULES_PATH = path.join(__dirname, "..", "..", "..", "firestore.rules");

const results = [];
function record(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"} — ${name}${detail ? " :: " + detail : ""}`);
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-fam-test",
    firestore: {
      rules: fs.readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });

  // ---------- seed data, bypassing rules ----------
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("families/famA").set({
      name: "Test Family",
      createdBy: "owner1",
      ownerUid: "owner1",
      joinCode: "ABC123",
      memberCount: 2,
    });
    await db.doc("families/famA/members/owner1").set({ uid: "owner1", displayName: "Owner", role: "owner" });
    await db.doc("families/famA/members/member2").set({ uid: "member2", displayName: "Member Two", role: "member" });

    await db.doc("families/famA/tasks/task1").set({
      assignerUid: "owner1",
      assigneeUid: "member2",
      title: "Clean room",
      description: "",
      status: "pending",
      rewardPoints: 50,
    });

    await db.doc("families/famA/chats/main/messages/msg1").set({
      authorUid: "member2",
      text: "hi",
      authorName: "Member Two",
    });
    await db.doc("families/famA/chats/main/messages/msg1/reports/owner1").set({
      reporterUid: "owner1",
      familyId: "famA",
      kind: "chat",
      targetAuthorUid: "member2",
      messageAuthorUid: "member2",
      preview: "hi",
    });

    // member_stats with a *recent* lastStatsWriteAt (simulate a write that
    // just happened), so the very next rules-gated write should be blocked.
    await db.doc("families/famA/member_stats/member2").set({
      points: 100,
      lastStatsWriteAt: new Date(),
    });
    // A second family, unrelated, to test that outsiders can't touch famA.
    await db.doc("families/famB").set({
      name: "Other Family",
      createdBy: "owner9",
      ownerUid: "owner9",
      joinCode: "ZZZ999",
      memberCount: 1,
    });
  });

  const owner1 = testEnv.authenticatedContext("owner1").firestore();
  const member2 = testEnv.authenticatedContext("member2").firestore();
  const member3 = testEnv.authenticatedContext("member3").firestore(); // signed in, NOT a member of famA
  const outsider9 = testEnv.authenticatedContext("owner9").firestore();

  // ===== 1) families/{fid}: get allowed, list denied =====
  await assertSucceeds(member3.doc("families/famA").get())
    .then(() => record("families get() allowed for any signed-in user", true))
    .catch((e) => record("families get() allowed for any signed-in user", false, e.message));

  await assertFails(
    member3.collection("families").where("joinCode", "==", "ABC123").get(),
  )
    .then(() => record("families list()/query denied (join-code brute force closed)", true))
    .catch((e) => record("families list()/query denied (join-code brute force closed)", false, e.message));

  // ===== 2) priorFamilyOwnerId() ternary: owner-only pinnedAnnouncement =====
  await assertFails(
    member2.doc("families/famA").update({
      pinnedAnnouncement: "member2 trying to pin",
      updatedAt: new Date(),
    }),
  )
    .then(() => record("non-owner cannot set pinnedAnnouncement", true))
    .catch((e) => record("non-owner cannot set pinnedAnnouncement", false, e.message));

  await assertSucceeds(
    owner1.doc("families/famA").update({
      pinnedAnnouncement: "owner announcement",
      updatedAt: new Date(),
    }),
  )
    .then(() => record("owner CAN set pinnedAnnouncement (priorFamilyOwnerId ternary correct)", true))
    .catch((e) => record("owner CAN set pinnedAnnouncement (priorFamilyOwnerId ternary correct)", false, e.message));

  // ===== 3) familyDocOwnerUid() ternary: owner-only report read =====
  await assertSucceeds(owner1.doc("families/famA/chats/main/messages/msg1/reports/owner1").get())
    .then(() => record("family owner can read chat report (familyDocOwnerUid ternary correct)", true))
    .catch((e) => record("family owner can read chat report (familyDocOwnerUid ternary correct)", false, e.message));

  // member3 is not a member of famA at all, so isMemberOf(fid) already blocks — use
  // member2 (a real member, but not the owner, not the reporter) for a true
  // familyDocOwnerUid()-specific negative case.
  await assertFails(member2.doc("families/famA/chats/main/messages/msg1/reports/owner1").get())
    .then(() => record("non-owner, non-reporter member cannot read chat report", true))
    .catch((e) => record("non-owner, non-reporter member cannot read chat report", false, e.message));

  // ===== 4) tasks/{taskId} update allowlist =====
  await assertSucceeds(
    member2.doc("families/famA/tasks/task1").update({ status: "submitted", submittedNote: "done", submittedAt: new Date() }),
  )
    .then(() => record("task status-only update allowed", true))
    .catch((e) => record("task status-only update allowed", false, e.message));

  await assertFails(
    owner1.doc("families/famA/tasks/task1").update({ status: "approved", rewardPoints: 9999 }),
  )
    .then(() => record("task update CANNOT smuggle rewardPoints change", true))
    .catch((e) => record("task update CANNOT smuggle rewardPoints change", false, e.message));

  // ===== 5) members/{uid} update allowlist =====
  await assertSucceeds(
    member2.doc("families/famA/members/member2").update({ displayName: "Member Two Updated" }),
  )
    .then(() => record("member self-update of allowlisted field succeeds", true))
    .catch((e) => record("member self-update of allowlisted field succeeds", false, e.message));

  await assertFails(
    member2.doc("families/famA/members/member2").update({ role: "owner" }),
  )
    .then(() => record("member CANNOT self-promote role via update", true))
    .catch((e) => record("member CANNOT self-promote role via update", false, e.message));

  // ===== 6) join-transaction memberCount branch =====
  // member3 has no members/{uid} doc under famA at all -> must be blocked
  // even though they're signed in.
  await assertFails(
    member3.doc("families/famA").update({ memberCount: 3, updatedAt: new Date() }),
  )
    .then(() => record("stranger cannot bump memberCount without a member doc", true))
    .catch((e) => record("stranger cannot bump memberCount without a member doc", false, e.message));

  // Simulate the real join sequence: member doc created first (as the join
  // transaction does), then the memberCount bump in the same shape of write.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("families/famA/members/member4").set({ uid: "member4", displayName: "Member Four" });
  });
  const member4 = testEnv.authenticatedContext("member4").firestore();
  await assertSucceeds(
    member4.doc("families/famA").update({ memberCount: 3, updatedAt: new Date() }),
  )
    .then(() => record("real joiner (member doc exists) CAN bump memberCount by 1", true))
    .catch((e) => record("real joiner (member doc exists) CAN bump memberCount by 1", false, e.message));

  // ===== 7) member_stats rate limit =====
  // member2's stats doc was seeded with lastStatsWriteAt = now (< 1s ago).
  await assertFails(
    member2.doc("families/famA/member_stats/member2").update({ points: 120 }),
  )
    .then(() => record("member_stats write blocked within 1s of lastStatsWriteAt", true))
    .catch((e) => record("member_stats write blocked within 1s of lastStatsWriteAt", false, e.message));

  // A brand-new stats doc (never written before) must NOT be blocked — the
  // rate-limit is deliberately lenient when the field was never set.
  await assertSucceeds(
    owner1.doc("families/famA/member_stats/owner1").set({ points: 10 }),
  )
    .then(() => record("member_stats CREATE with no prior lastStatsWriteAt is never blocked (lenient by design)", true))
    .catch((e) => record("member_stats CREATE with no prior lastStatsWriteAt is never blocked (lenient by design)", false, e.message));

  await testEnv.cleanup();

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} rules assertions passed.`);
  if (failed.length > 0) {
    console.log("FAILED:", failed.map((f) => f.name));
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("Test harness crashed:", e);
  process.exitCode = 1;
});

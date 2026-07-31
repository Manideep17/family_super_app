"use strict";
// Executes the REAL compiled Cloud Functions handlers (functions/lib/*.js,
// built from src/*.ts via `npm run build`) against a minimal in-memory
// Firestore/Auth stand-in (./fake-firestore.js) -- no emulator, no network,
// no real GCP project touched. Only the admin-SDK I/O surface is faked;
// none of the business logic under test is reimplemented or mocked.
//
// Run with: npm run build && node test/logic.test.js
const admin = require("firebase-admin");
const { installFakeAdmin } = require("./fake-firestore.js");
const { db, deletedAuthUsers } = installFakeAdmin(admin);

const { resolveJoinCode, allocateJoinCode } = require("../lib/join_codes.js");
const { weeklyChampionRollup } = require("../lib/weekly.js");
const { deleteAccount } = require("../lib/account.js");

const results = [];
function record(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"} — ${name}${detail ? " :: " + String(detail).slice(0, 200) : ""}`);
}
async function expectThrow(promise, checkFn, name) {
  try {
    await promise;
    record(name, false, "did not throw");
  } catch (e) {
    const ok = checkFn(e);
    record(name, ok, ok ? undefined : `unexpected error: ${e.code || e.message}`);
  }
}
async function expectOk(promise, name, checkFn) {
  try {
    const result = await promise;
    const ok = checkFn ? checkFn(result) : true;
    record(name, ok, ok ? undefined : `unexpected result: ${JSON.stringify(result)}`);
    return result;
  } catch (e) {
    record(name, false, `threw unexpectedly: ${e.code || e.message}`);
  }
}

async function main() {
  // ===================================================================
  // join_codes.ts — resolveJoinCode / allocateJoinCode
  // ===================================================================
  db._setDoc("families/famA", { name: "Test Family", joinCode: "ABC123", createdBy: "owner1", ownerUid: "owner1" });

  await expectThrow(
    resolveJoinCode.run({ data: { joinCode: "abc123" } }), // no auth field at all
    (e) => e.code === "unauthenticated",
    "resolveJoinCode: rejects unauthenticated caller",
  );

  await expectOk(
    resolveJoinCode.run({ auth: { uid: "someone" }, data: { joinCode: "abc123" } }),
    "resolveJoinCode: lowercase code resolves to the right family (case-insensitive)",
    (r) => r.familyId === "famA" && r.name === "Test Family",
  );

  await expectThrow(
    resolveJoinCode.run({ auth: { uid: "someone" }, data: { joinCode: "ZZZZZZ" } }),
    (e) => e.code === "not-found",
    "resolveJoinCode: unknown code throws not-found",
  );

  const allocated = await expectOk(
    allocateJoinCode.run({ auth: { uid: "someone" }, data: {} }),
    "allocateJoinCode: returns a fresh 6-char code from the expected alphabet",
    (r) =>
      typeof r.joinCode === "string" &&
      r.joinCode.length === 6 &&
      /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(r.joinCode) &&
      r.joinCode !== "ABC123",
  );

  // ===================================================================
  // weekly.ts — weeklyChampionRollup: delta-based champion + weekStart reset
  // + per-family try/catch isolation
  // ===================================================================
  db._setDoc("families/famB", { name: "Poison Family" }); // will simulate a read failure
  db.poisonPaths.add("families/famB/member_stats");

  db._setDoc("families/famA/member_stats/alice", { points: 500, weekStartPoints: 480, displayName: "Alice" }); // delta 20
  db._setDoc("families/famA/member_stats/bob", { points: 1000, weekStartPoints: 950, displayName: "Bob" }); // delta 50 <- should win
  db._setDoc("families/famA/member_stats/carol", { points: 2000, weekStartPoints: 1990, displayName: "Carol" }); // delta 10, but highest lifetime total

  await weeklyChampionRollup.run({}).catch((e) => record("weeklyChampionRollup: run() did not crash the whole batch", false, e.message));
  record("weeklyChampionRollup: run() did not crash the whole batch (famB poisoned, famA still processed)", true);

  const champion = (await db.collection("families/famA/gamification").doc("weekly_champion").get()).data();
  record(
    "weeklyChampionRollup: crowns highest WEEKLY DELTA (bob), not highest lifetime total (carol)",
    !!champion && champion.championUid === "bob" && champion.championPoints === 50,
    champion ? JSON.stringify(champion) : "no champion doc written",
  );

  const bobAfter = (await db.collection("families/famA/member_stats").doc("bob").get()).data();
  const carolAfter = (await db.collection("families/famA/member_stats").doc("carol").get()).data();
  record(
    "weeklyChampionRollup: resets every member's weekStartPoints baseline for the new week",
    bobAfter.weekStartPoints === 1000 && carolAfter.weekStartPoints === 2000,
    JSON.stringify({ bobAfter, carolAfter }),
  );

  // ===================================================================
  // account.ts — deleteAccount: owner reassignment picks the EARLIEST-
  // JOINED remaining member, not just "any other member"
  // ===================================================================
  db._setDoc("users/owner1", { familyId: "famA" });
  db._setDoc("families/famA/members/owner1", { uid: "owner1", joinedAt: new Date("2024-01-01") });
  db._setDoc("families/famA/members/member2", { uid: "member2", joinedAt: new Date("2024-02-01") }); // joined later
  db._setDoc("families/famA/members/member3", { uid: "member3", joinedAt: new Date("2024-01-15") }); // joined EARLIER than member2

  const delRes = await expectOk(
    deleteAccount.run({ auth: { uid: "owner1" }, data: {} }),
    "deleteAccount: returns ok with familyWiped=false (other members remain)",
    (r) => r.ok === true && r.familyId === "famA" && r.familyWiped === false,
  );

  const famAfter = (await db.collection("families").doc("famA").get()).data();
  record(
    "deleteAccount: reassigns ownerUid to the EARLIEST-joined remaining member (member3, not member2)",
    famAfter.ownerUid === "member3",
    `ownerUid=${famAfter.ownerUid}`,
  );

  const ownerMemberDocGone = !(await db.collection("families/famA/members").doc("owner1").get()).exists;
  const userDocGone = !(await db.collection("users").doc("owner1").get()).exists;
  record("deleteAccount: departing owner's member doc is removed", ownerMemberDocGone);
  record("deleteAccount: departing owner's users/ pointer doc is removed", userDocGone);
  record("deleteAccount: calls admin.auth().deleteUser() for the departing uid", deletedAuthUsers.includes("owner1"), JSON.stringify(deletedAuthUsers));

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} function-logic assertions passed.`);
  if (failed.length > 0) {
    console.log("FAILED:", failed.map((f) => f.name));
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("Test harness crashed:", e);
  process.exitCode = 1;
});

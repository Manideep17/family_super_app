"use strict";
// Executes the REAL compiled referrals.ts handlers against the same
// in-memory Firestore/Auth stand-in used by logic.test.js. See that file
// and ./fake-firestore.js for why this approach (no emulator, no network).
const admin = require("firebase-admin");
const { installFakeAdmin } = require("./fake-firestore.js");
const { db } = installFakeAdmin(admin);

const { allocateReferralCode, redeemReferralCode } = require("../lib/referrals.js");

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
  db._setDoc("families/famReferrer", { name: "Referrer Family" });
  db._setDoc("families/famReferrer/members/uidReferrer", { uid: "uidReferrer" });
  db._setDoc("families/famNewbie", { name: "New Family" });
  db._setDoc("families/famNewbie/members/uidNewbie", { uid: "uidNewbie" });
  db._setDoc("families/famStranger", { name: "Third Family" });
  db._setDoc("families/famStranger/members/uidStranger", { uid: "uidStranger" });

  await expectThrow(
    allocateReferralCode.run({ data: { familyId: "famReferrer" } }),
    (e) => e.code === "unauthenticated",
    "allocateReferralCode: rejects unauthenticated caller",
  );

  await expectThrow(
    allocateReferralCode.run({ auth: { uid: "someoneElse" }, data: { familyId: "famReferrer" } }),
    (e) => e.code === "permission-denied",
    "allocateReferralCode: rejects a caller who isn't a member of that family",
  );

  const alloc1 = await expectOk(
    allocateReferralCode.run({ auth: { uid: "uidReferrer" }, data: { familyId: "famReferrer" } }),
    "allocateReferralCode: mints a valid 6-char code",
    (r) => typeof r.referralCode === "string" && /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/.test(r.referralCode),
  );

  const alloc2 = await expectOk(
    allocateReferralCode.run({ auth: { uid: "uidReferrer" }, data: { familyId: "famReferrer" } }),
    "allocateReferralCode: idempotent (calling again returns the SAME code)",
    (r) => r.referralCode === alloc1.referralCode,
  );
  void alloc2;

  const code = alloc1.referralCode;

  await expectThrow(
    redeemReferralCode.run({
      auth: { uid: "uidReferrer" },
      data: { familyId: "famReferrer", referralCode: code },
    }),
    (e) => e.code === "invalid-argument",
    "redeemReferralCode: a family cannot redeem its own code",
  );

  await expectThrow(
    redeemReferralCode.run({
      auth: { uid: "uidNewbie" },
      data: { familyId: "famNewbie", referralCode: "ZZZZZZ" },
    }),
    (e) => e.code === "not-found",
    "redeemReferralCode: unknown code throws not-found",
  );

  await expectOk(
    redeemReferralCode.run({
      auth: { uid: "uidNewbie" },
      data: { familyId: "famNewbie", referralCode: code },
    }),
    "redeemReferralCode: successful redemption returns ok",
    (r) => r.ok === true && r.bonusDays === 7,
  );

  const newbieAfter = (await db.collection("families").doc("famNewbie").get()).data();
  const referrerAfter = (await db.collection("families").doc("famReferrer").get()).data();
  record(
    "redeemReferralCode: redeemer family gets referredByFamilyId + a live referralBonusExpiresAt",
    newbieAfter.referredByFamilyId === "famReferrer" &&
      newbieAfter.referralBonusExpiresAt.toMillis() > Date.now(),
    JSON.stringify({ referredByFamilyId: newbieAfter.referredByFamilyId }),
  );
  record(
    "redeemReferralCode: referrer family gets referralCount incremented + a live referralBonusExpiresAt",
    referrerAfter.referralCount === 1 && referrerAfter.referralBonusExpiresAt.toMillis() > Date.now(),
    JSON.stringify({ referralCount: referrerAfter.referralCount }),
  );

  await expectThrow(
    redeemReferralCode.run({
      auth: { uid: "uidNewbie" },
      data: { familyId: "famNewbie", referralCode: code },
    }),
    (e) => e.code === "already-exists",
    "redeemReferralCode: a family cannot redeem a second referral code",
  );

  // A second real family redeems the SAME referrer's code -- referrer's
  // bonus should STACK (extend further into the future), not reset.
  const beforeStrangerRedeem = referrerAfter.referralBonusExpiresAt.toMillis();
  await expectOk(
    redeemReferralCode.run({
      auth: { uid: "uidStranger" },
      data: { familyId: "famStranger", referralCode: code },
    }),
    "redeemReferralCode: a second redemption stacks the referrer's bonus further out",
    (r) => r.ok === true,
  );
  const referrerAfter2 = (await db.collection("families").doc("famReferrer").get()).data();
  record(
    "redeemReferralCode: referrer's bonus expiry moved further out after the second redemption",
    referrerAfter2.referralBonusExpiresAt.toMillis() > beforeStrangerRedeem &&
      referrerAfter2.referralCount === 2,
    JSON.stringify({
      before: beforeStrangerRedeem,
      after: referrerAfter2.referralBonusExpiresAt.toMillis(),
      referralCount: referrerAfter2.referralCount,
    }),
  );

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} referral assertions passed.`);
  if (failed.length > 0) {
    console.log("FAILED:", failed.map((f) => f.name));
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error("Test harness crashed:", e);
  process.exitCode = 1;
});

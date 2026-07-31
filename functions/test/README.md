# Backend tests

Two independent suites, added after the July 2026 bug-fix audit to replace
"read the diff and trust it" with something that actually executes.

## `npm test` — function logic (`logic.test.js`)

Runs the **real compiled handlers** (`lib/join_codes.js`, `lib/weekly.js`,
`lib/account.js` — built from `src/*.ts` by `npm run build`) against a tiny
in-memory Firestore/Auth stand-in (`fake-firestore.js`). No emulator, no
network, no real Firebase project touched — only the admin-SDK I/O calls are
faked; none of the business logic under test is reimplemented.

Covers:
- `resolveJoinCode` / `allocateJoinCode` — auth checks, case-insensitive
  lookup, not-found, alphabet/uniqueness of allocated codes.
- `weeklyChampionRollup` — crowns the highest **weekly delta**, not highest
  lifetime total; resets `weekStartPoints` for the new week; one poisoned
  family's failure doesn't stop other families from being processed.
- `deleteAccount` — reassigns `ownerUid` to the **earliest-joined**
  remaining member when the departing user was the owner; cleans up the
  member doc, `users/` pointer, and calls `admin.auth().deleteUser`.

Run: `npm run build && node test/logic.test.js` (or `npm test`).

## `npm run test:rules` — Firestore Rules (`rules/rules.test.mjs`)

Uses `@firebase/rules-unit-testing` against a real Firestore Rules emulator
to exercise the rules fixes directly: `families/{fid}` get-allowed/list-denied
split, the owner-only ternary functions (`priorFamilyOwnerId`,
`familyDocOwnerUid`), the `tasks`/`members` field allowlists, the
join-transaction membership check, and the `member_stats` write rate limit.

**Requires Java 21+ and a working connection to
`storage.googleapis.com`** (to download the Firestore emulator JAR on first
run) — neither was available in the sandbox this was written in, so this
suite is untested as of this commit. It's included so it can be run for real
on a normal dev machine or in CI: `npm run test:rules`.

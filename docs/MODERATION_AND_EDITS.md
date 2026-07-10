# Moderation, reports inbox, and who can edit what

## Reports (chat & diary)

- New report writes include `familyId`, `kind` (`chat` | `diary`), `targetAuthorUid`, and a short `preview`. Legacy report docs without `familyId` still work for direct reads but **do not appear** in the owner’s collection-group inbox.
- **Family owner** (`families/{fid}.ownerUid`, falling back to `createdBy`) can open **My family → Reports inbox** and see a read-only list fed by `collectionGroup('reports')`.
- **Deploy** updated [`firestore.rules`](../firestore.rules) and the composite index in [`firestore.indexes.json`](../firestore.indexes.json) (`reports`: `familyId` ASC, `createdAt` DESC, `COLLECTION_GROUP`). Use Firebase CLI / console as you normally deploy.

Firestore security: only reporters and the family owner can read a given report doc; the collection-group query is allowed for the owner because every matching document passes rules for that user.

## Optional “hide on my phone”

After reporting, members can opt in to **hide** the chat message or diary story **on this device only** (SharedPreferences). **My family → Show hidden content again** clears those local lists.

## Owner expectations for games / points

Families should treat leaderboard points as **lightweight fun**. If someone clearly games the system, the escape hatch remains **server-side validation** (callable) as sketched in [`BACKEND_INTEGRITY_AND_AI_GATE.md`](BACKEND_INTEGRITY_AND_AI_GATE.md). **Android betas** validate behavior on release APKs — iOS is out of scope until that platform ships again.

## Audit: family-wide and sensitive fields (Firestore rules)

| Area | Who can change it |
|------|-------------------|
| Family **name**, **memberCount** | Any member (with rule constraints on `memberCount` / join flow). |
| **pinnedAnnouncement** | **Owner only** (same uid as `ownerUid` or legacy `createdBy`). |
| **dailyDigestOptIn** | **Owner only**. |
| **ownerUid** transfer | **Current owner** only; target must be an existing member. |
| **Members** `members/{uid}` | Each user updates **their own** doc. |
| **Chat** messages | Author can update/delete own message; anyone can report. |
| **Diary** stories | Author can update/delete own story; others can report. |
| **Calendar** events | **Creatoronly** for update/delete. |
| **Vault** items | **Uploaderonly** for update/delete. |
| **Tasks** | Assignee / assigner (and assignee by email match) per transition rules. |
| **Polls** | **Creator** closes or deletes; each member writes own **response** doc. |
| **Predictions / creative / time travel** | **Authoronly** for delete where applicable. |
| **future_predictions** | **Votes:** any member may `update`, but **only** the `votes` map, and **`votes.diff` must affect only `request.auth.uid`** (cannot rewrite others’ votes). **Immutable** on vote writes: author, text, names, emails, targets, timestamps, unresolved state. **Resolve:** **`authorUid` only** may set `resolved`, `outcome` (`yes` \| `no`), `resolvedAt`; `votes` unchanged. |
| **reels** | **Reactions:** any member may `update`, but **only** the `reactions` map, and **`reactions.diff` must affect only `request.auth.uid`**. **Immutable:** title, theme, author fields, media URLs/paths, `createdAt`. |

### Rules audit note (collaborative maps)

Both games store per-user choices in a **top-level map** (`votes`, `reactions`). Broad `allow update: if isMemberOf(fid)` would let a modified client rewrite another member’s key or other fields. The rules now constrain updates to **self-only map keys** plus **author-only resolve** for predictions, matching the Flutter clients in [`future_predictions_game_screen.dart`](../lib/features/games/presentation/screens/future_predictions_game_screen.dart) and [`reel_battle_screen.dart`](../lib/features/games/presentation/screens/reel_battle_screen.dart).

For full detail, see [`firestore.rules`](../firestore.rules).

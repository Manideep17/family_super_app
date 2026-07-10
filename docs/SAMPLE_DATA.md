# Sample data (Firestore)

Use these paths after Phase 1 chat/diary/tasks are wired. IDs are examples — use your real UIDs from Firebase Auth.

## `users/{uid}`

| Field | Type | Example |
|-------|------|---------|
| `email` | string | `member@example.com` |
| `displayName` | string | `Member` |
| `role` | string | `member` |
| `avatarUrl` | string? | `https://...` |
| `points` | number | `120` |
| `createdAt` | timestamp | server |

## `chats/family` (document)

| Field | Type | Notes |
|-------|------|--------|
| `members` | map | uid → `{ email, name, updatedAt? }` — roster for read receipts |
| `readThrough` | map | uid → timestamp — cursor for “seen” ticks |

## `chats/family/messages/{messageId}`

| Field | Type |
|-------|------|
| `text` | string |
| `authorUid` | string |
| `authorName` | string |
| `createdAt` | timestamp |
| `type` | string (`text` or `voice`) |
| `audioUrl` | string? |
| `reactions` | map uid → emoji string |

## `stories/{storyId}`

| Field | Type |
|-------|------|
| `title` | string |
| `body` | string |
| `mood` | string (`happy`, `fun`, `grateful`, `calm`, `excited`, `love`, `proud`, `sad`) |
| `authorUid` | string |
| `authorName` | string |
| `authorEmail` | string (lowercase; timeline “involves person”) |
| `taggedEmails` | array of string (family emails, lowercased) |
| `imageUrls` | array of string |
| `videoUrls` | array of string |
| `reactions` | map uid → emoji |
| `commentCount` | number |
| `createdAt` | timestamp |

## `stories/{storyId}/comments/{commentId}`

| Field | Type |
|-------|------|
| `text` | string |
| `authorUid` | string |
| `authorName` | string |
| `createdAt` | timestamp |

## `tasks/{taskId}`

| Field | Type |
|-------|------|
| `title` | string |
| `description` | string |
| `assignerUid` | string |
| `assignerEmail` | string (lowercase) |
| `assignerName` | string |
| `assigneeEmail` | string (lowercase) |
| `assigneeName` | string |
| `participantEmails` | array of string — `[assignerEmail, assigneeEmail]` unique, for queries |
| `assigneeUid` | string (set when assignee submits; used for reward points) |
| `dueAt` | timestamp |
| `rewardPoints` | number |
| `status` | string (`pending`, `submitted`, `approved`, `rejected`) |
| `createdAt` | timestamp |
| `submittedNote` | string? |
| `submittedAt` | timestamp? |
| `rejectedReason` | string? |
| `resolvedAt` | timestamp? |

## `calendar_events/{eventId}`

| Field | Type |
|-------|------|
| `title` | string |
| `description` | string |
| `startAt` | timestamp |
| `endAt` | timestamp? |
| `allDay` | bool |
| `eventType` | string (`birthday`, `trip`, `reminder`, `other`) |
| `creatorUid` | string |
| `creatorName` | string |
| `creatorEmail` | string (lowercase) |
| `participantEmails` | array of string (lowercase, includes creator) |

## `vault_items/{itemId}`

| Field | Type |
|-------|------|
| `title` | string |
| `downloadUrl` | string |
| `storagePath` | string (Storage path for delete) |
| `uploaderUid` | string |
| `uploaderName` | string |
| `uploaderEmail` | string |
| `personTags` | array of string (family emails) |
| `eventTag` | string? |
| `contentType` | string |
| `createdAt` | timestamp |

## `member_stats/{uid}`

| Field | Type |
|-------|------|
| `email` | string |
| `displayName` | string |
| `points` | number |
| `storiesCreated` | number |
| `gamesWon` | number |
| `updatedAt` | timestamp? |

## `predictions/{predictionId}`

| Field | Type |
|-------|------|
| `text` | string |
| `predictorUid` | string |
| `predictorName` | string |
| `createdAt` | timestamp |
| `revealed` | bool |
| `outcomeNote` | string? |
| `revealedAt` | timestamp? |

## `users/{uid}`

| Field | Type |
|-------|------|
| `email` | string |
| `displayName` | string |
| `role` | string (`member`) |
| `avatarUrl` | string? |
| `fcmToken` | string? |
| `fcmTokenUpdatedAt` | timestamp? |
| `updatedAt` | timestamp? |

## `time_travel_entries/{id}`

| Field | Type |
|-------|------|
| `storyId` | string |
| `storyTitle` | string |
| `storyImageUrl` | string? |
| `response` | string |
| `authorUid` | string |
| `authorName` | string |
| `createdAt` | timestamp |

## `creative_submissions/{id}`

| Field | Type |
|-------|------|
| `promptKey` | string (`yyyy-MM-dd`) |
| `body` | string |
| `authorUid` | string |
| `authorName` | string |
| `createdAt` | timestamp |

## `gamification/weekly_champion` (document)

| Field | Type |
|-------|------|
| `weekId` | string (e.g. `2026-W5` — week bucket from app) |
| `championUid` | string |
| `championName` | string |
| `championPoints` | number |
| `updatedAt` | timestamp |

You can now seed demo data with:

```bash
cd "/Users/manideepbiswas/Downloads/Code/family_super_app/functions" && npm run seed:demo -- --join-code ABC123 --wipe-demo --service-account "/absolute/path/firebase-adminsdk.json"
```

Or:

```bash
cd "/Users/manideepbiswas/Downloads/Code/family_super_app/functions" && npm run seed:demo -- --family-id <FAMILY_ID> --wipe-demo --service-account "/absolute/path/firebase-adminsdk.json"
```

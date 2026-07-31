# Firebase setup (Family Super App)

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) and create a project (e.g. `your-family-app`).
2. Add an **Android** app with package name **`com.family.superapp`** (must match `android/app/build.gradle.kts` and the committed template `google-services.json`). When you are ready for iOS, add an iOS app with bundle ID **`com.family.superapp`** (see `lib/core/firebase/firebase_options.dart`).

## 2. Enable products

| Product | Use |
|--------|-----|
| **Authentication** | Email/Password + Google provider |
| **Cloud Firestore** | Chat, diary, tasks, profiles |
| **Storage (optional)** | Legacy media path; current app prefers Cloudinary for no-cost uploads |
| **Cloud Functions (required for sign-up)** | `resolveJoinCode`/`allocateJoinCode` (join-code lookup/allocation) must be deployed before anyone can create or join a family — see docs/PRODUCT_STRATEGY_AND_ENGAGEMENT.md bug-fix notes. Everything else Functions-related stays optional with Spark-safe fallbacks. |
| **Cloud Messaging** | Push notifications |

### Authentication

- Build → Authentication → Sign-in method → enable **Email/Password** and **Google**.
- For **Google on Android**, register the app’s **SHA-1** (debug and release) in Firebase project settings; run `./gradlew signingReport` from the `android/` folder after `flutter pub get` has created `local.properties`.
- For Google on iOS, add the reversed client ID to URL types (FlutterFire documents this).

### Firestore (starter rules — tighten before production)

Use rules that only allow your four UIDs or emails after you verify them (example pattern):

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Add matches for messages, stories, tasks with family checks
  }
}
```

**Important:** The app no longer uses a hardcoded family allowlist file. Access control is based on membership under `families/{familyId}/members/{uid}` and Firestore rules.

### Family chat (`chats/family`)

The app uses:

- Document `chats/family` — fields `members` (uid → `{ email, name }`) and `readThrough` (uid → timestamp).
- Subcollection `chats/family/messages/{messageId}` — `text`, `authorUid`, `authorName`, `createdAt`, `type`, optional `audioUrl`, `reactions` (uid → emoji).

**Development rules (replace with family-membership checks for production):**

```text
match /chats/family {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
  match /messages/{messageId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null
      && request.resource.data.authorUid == request.auth.uid;
    // Reactions: allow updates only from signed-in users (tighten with field masks in production)
    allow update: if request.auth != null;
    allow delete: if false;
  }
}
```

For production, restrict `update` on messages (e.g. only `reactions` changing) and restrict `chats/family` writes so `members` / `readThrough` cannot be tampered with arbitrarily.

### Diary (`stories`)

- Collection `stories` — one document per memory (see `docs/SAMPLE_DATA.md`).
- Subcollection `stories/{storyId}/comments/{commentId}` — threaded discussion.

**Development rules (tighten for production):**

```text
match /stories/{storyId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
    && request.resource.data.authorUid == request.auth.uid;
  allow update: if request.auth != null;
  match /comments/{commentId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null
      && request.resource.data.authorUid == request.auth.uid;
    allow update, delete: if false;
  }
}
```

For production, restrict `stories` updates (e.g. only `reactions` and `commentCount` / server fields) and ensure only family members can write.

### Tasks (`tasks`)

- Collection `tasks` — anyone in the family can create a task for anyone else (`participantEmails` includes both parties).
- Assignee submits (`status: submitted`); **assigner** approves or rejects.

**Development rules (tighten for production):**

```text
match /tasks/{taskId} {
  allow read, create, update: if request.auth != null;
}
```

For production, require `request.auth.token.email` (lowercased in your Auth users) to appear in `resource.data.participantEmails` for reads, and validate field-level updates (assignee vs assigner).

### Calendar (`calendar_events`)

**Development rules:**

```text
match /calendar_events/{eventId} {
  allow read, create, update, delete: if request.auth != null;
}
```

### Vault metadata (`vault_items`)

**Development rules:**

```text
match /vault_items/{id} {
  allow read, create, update, delete: if request.auth != null;
}
```

### Phase 3 — Gamification (`member_stats`)

**Development rules:**

```text
match /member_stats/{uid} {
  allow read: if request.auth != null;
  allow create, update: if request.auth != null && request.auth.uid == uid;
  allow delete: if false;
}
```

For production, only allow `points` / counters to change via **Cloud Functions** (trusted increments) if you need strict anti-cheat.

### Phase 3 — `gamification/weekly_champion` (single doc)

The app writes this document when the leaderboard updates (client-side “who is ahead this week”). **Development rules:**

```text
match /gamification/weekly_champion {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

For production, prefer computing the champion in a **scheduled Cloud Function** instead of trusting the client.

### Phase 3 — `predictions`

- Collection `predictions` — `text`, `predictorUid`, `predictorName`, `createdAt`, `revealed`, optional `outcomeNote`, `revealedAt`.

**Development rules:**

```text
match /predictions/{id} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
    && request.resource.data.predictorUid == request.auth.uid;
  allow update: if request.auth != null
    && resource.data.predictorUid == request.auth.uid;
  allow delete: if false;
}
```

Tighten `update` so only `revealed`, `outcomeNote`, and `revealedAt` can change after create.

### Profiles & FCM (`users/{uid}`)

The app merges `email`, `displayName`, `greeting`, optional `avatarUrl`, and `fcmToken` (see `UserProfileRepository`, `FcmBootstrap`).

**Development rules:**

```text
match /users/{userId} {
  allow read: if request.auth != null;
  allow create, update: if request.auth != null && request.auth.uid == userId;
  allow delete: if false;
}
```

### Time travel & creative games

**`time_travel_entries`** — responses to diary memories.

**`creative_submissions`** — daily creative wall (prompt key is `yyyy-MM-dd`).

**Development rules:**

```text
match /time_travel_entries/{id} {
  allow read, create: if request.auth != null;
  allow update, delete: if false;
}

match /creative_submissions/{id} {
  allow read, create: if request.auth != null;
  allow update, delete: if false;
}
```

Tighten so `authorUid` must match `request.auth.uid` on create.

### Cloud Storage (`vault/{uid}/…` and avatars)

**Development rules:**

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /vault/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Push reminders (Phase 2+)

The app stores the device **FCM token** on `users/{uid}` after permission is granted. Sending pushes for messages, tasks, and calendar still needs **Cloud Functions** (or another backend) that reads those tokens and calls FCM. Scheduled calendar reminders also need Functions or on-device scheduling.

## 3. FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
cd family_super_app
flutterfire configure
```

This overwrites `lib/core/firebase/firebase_options.dart` with real keys. Add `firebase_options.dart` to `.gitignore` if the repo is public.

## 4. iOS extras

- Download `GoogleService-Info.plist` into `ios/Runner/` (FlutterFire does this).
- Enable **Keychain Sharing** if you use Google Sign-In across extensions.
- Set minimum iOS version per `google_sign_in` / Firebase docs.

## 5. Android extras

- Download `google-services.json` into `android/app/` (FlutterFire does this).
- In `android/build.gradle` and `android/app/build.gradle`, apply the Google services plugin as in [FlutterFire Android install](https://firebase.google.com/docs/flutter/setup?platform=android).

## 6. Create tester accounts

1. In Authentication, manually add users or let each person register once.
2. Sign in, create one family, and share the invite code with other testers.
3. Optionally store `users/{uid}` with `displayName`, `greeting`, and `avatarUrl` for richer profiles.

## 7. Indexes

When you add chat and diary queries, create composite indexes from the links in the Firebase console error messages.

If `predictions` queries fail, add a single-field index on `createdAt` (Firestore usually auto-indexes fields used in `orderBy`; follow any console link if not).

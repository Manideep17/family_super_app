# Folder structure

```
lib/
├── main.dart                 # Binding, ProviderScope, Firebase init
├── app.dart                  # MaterialApp.router, theme
├── core/
│   ├── firebase/             # Bootstrap + firebase_options (from FlutterFire)
│   ├── fcm/                  # FCM permission bootstrap
│   ├── router/               # go_router, refresh on auth stream
│   └── theme/                # Light/dark theme tokens
└── features/
    ├── auth/
    │   ├── data/             # Repository impl, allowlist, DTOs → Firestore mappers
    │   ├── domain/           # Entities, repository contracts, use cases (grow here)
    │   └── presentation/     # Screens, widgets, Riverpod notifiers
    ├── home/
    │   └── presentation/     # Shell, dashboard (Phase 1+)
    ├── chat/
    │   ├── data/             # ChatRepositoryImpl (Firestore)
    │   ├── domain/           # ChatMessage, FamilyChatMeta, ChatRepository
    │   └── presentation/     # FamilyChatScreen, bubbles, providers
    ├── diary/
    │   ├── data/             # DiaryRepositoryImpl
    │   ├── domain/           # Story, StoryComment, DiaryRepository
    │   └── presentation/     # DiaryFeedScreen, CreateStory, Detail, StoryCard, moods
    ├── tasks/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── timeline/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── calendar/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── vault/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── gamification/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── profile/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── games/
        ├── data/
        ├── domain/
        └── presentation/
```

**Clean Architecture (per feature)**

- **Presentation:** UI only; depends on domain via abstractions + Riverpod.
- **Domain:** entities, repository interfaces, use cases (no Flutter/Firebase imports).
- **Data:** implements repositories; talks to Firebase / local cache.

Shared widgets live under `lib/core/widgets/` as they appear.

**Tests** (add as you stabilize): `test/` mirrors `lib/` with `_test.dart` suffix.

# FAM revamp roadmap — $0 budget, testing phase

Goal: make FAM feel aesthetically polished, feature-rich, and genuinely useful to an Indian family — using only free-tier tech until the app is out of testing. See [AI_LOGIC_SETUP.md](AI_LOGIC_SETUP.md) for the two console steps this roadmap depends on.

## Phase 0 — unblock the backend (manual, ~15 minutes, still $0)

Nothing below this line matters if the backend isn't live. Do this first:

- [x] Attach Blaze billing — **done**. Next: set a $0 budget alert (Section 1, step 3 of `AI_LOGIC_SETUP.md`) if you haven't, then deploy Functions/rules/indexes via either the new `.github/workflows/deploy-firebase.yml` (Actions tab → "Deploy Firebase Backend") or the local CLI commands — both are spelled out in Section 1, step 5.
- [ ] Enable Firebase AI Logic with the Gemini Developer API backend (Section 2 of `AI_LOGIC_SETUP.md`) — no billing needed for this one, separate from Blaze.
- [ ] Rebuild with `--dart-define=FUNCTIONS_ENABLED=true --dart-define=AI_DIGEST_ENABLED=true` (add to whatever flags you already pass, e.g. `MEDIA_UPLOADS_ENABLED`) — `build-apk.yml` now has checkboxes for all three on manual runs.

`functions/src` was verified to build cleanly (`npm install && npm run build`, zero TypeScript errors) and `firestore.indexes.json`/`firebase.json` were checked for valid JSON — so the deploy itself should be uneventful once you run it.

## Phase 1 — shipped this session (code, needs `flutter pub get` + a real build to verify)

| Area | What changed | Files |
|---|---|---|
| Design | Material 3 Expressive pass: pill FAB, badge/tooltip theming, stadium nav indicator, deterministic per-member accent color used on the Home hero avatar | `lib/core/theme/app_theme.dart`, `lib/features/home/presentation/screens/dashboard_screen.dart` |
| Gamification | Per-member streaks (`currentStreak`/`longestStreak`) persisted on `member_stats`, folded into existing point-awarding writes (story created, task approved, game won) — no new write paths. Milestone coin bonuses at 3/7/30/100 days, one-time via `streakMilestonesClaimed`. New streak badges on the leaderboard. | `lib/features/gamification/domain/streak_milestones.dart`, `.../domain/entities/member_stats.dart`, `.../data/gamification_repository_impl.dart`, `.../presentation/badge_catalog.dart`, `.../presentation/screens/leaderboard_screen.dart` |
| Intelligence (on-device, free) | Vault photos are OCR'd on-device (Google ML Kit — no network, no quota) before upload; detected text is stored and shown in the photo detail view and flagged with an icon on the grid tile | `lib/core/media/text_extraction_service.dart`, `lib/features/vault/**` |
| Intelligence (Gemini, free tier) | New "Weekly digest" screen: summarizes the week's diary entries, approved tasks, and upcoming events into a short warm recap via Gemini (Firebase AI Logic, Gemini Developer API backend — no Blaze). Off by default behind `AppFlags.aiDigestEnabled` until the console step is done. | `lib/core/ai/family_digest_service.dart`, `lib/features/insights/presentation/screens/weekly_digest_screen.dart` |
| Family-specific / fun | Indian festival banner on Home — surfaces the next festival within 21 days and one-taps into a pre-titled diary entry ("Our Diwali this year") so adding a tradition/photo takes no typing | `lib/core/festivals/indian_festivals.dart`, dashboard `_FestivalBanner` |

**Also this session:** added `.github/workflows/deploy-firebase.yml` (one-click Functions/rules/indexes/storage deploy via a service-account secret — no local Firebase CLI needed), added the missing `node_modules/`/`functions/lib/` entries to `.gitignore` (they weren't ignored before, so a stray `git add .` after building functions locally would have committed them), and added an `ai_digest_enabled` checkbox to `build-apk.yml` alongside the existing two.

**Before you ship this:** run `flutter pub get` (three new packages: `firebase_ai`, `google_mlkit_text_recognition`, `google_mlkit_entity_extraction`) and `flutter analyze`. This session's sandbox has no Flutter SDK, so none of the above has been compiled or run — treat it as a reviewed-but-unverified diff, not a tested one. The ML Kit entity-extraction API surface in particular is worth a close look against the installed package version.

## Phase 2 — next up (not started)

- Retire the `FreePushBridge` client-side notification workaround once real Functions triggers are confirmed live (Phase 0).
- Extend per-member accent colors beyond the Home avatar — task cards, diary author tags, family roster.
- Vault search by `extractedText` (the field now exists; no UI to search it yet).
- Multi-generational accessibility pass: larger touch targets/text scale option, voice input on diary entries for family members less comfortable typing English.
- Extend `IndianFestivals.year2026` to 2027 before the year turns over — most festival dates move every year (see the accuracy caveat in that file); the lunar/moon-sighting ones especially need re-verification, not a fixed offset.

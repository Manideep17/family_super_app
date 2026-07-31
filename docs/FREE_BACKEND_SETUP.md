# Free Backend Setup (Spark + Cloudflare + OneSignal)

This app can run Blaze-like features without Firebase Blaze by combining Spark with free services.

**Superseded, once you're on Blaze**: media uploads (diary/avatar/vault/reel)
now go straight to Firebase Storage (`lib/core/media/media_upload_service.dart`
+ `storage.rules`) — no Cloudinary account or extra dart-defines needed,
just `--dart-define=MEDIA_UPLOADS_ENABLED=true` (already the CI default).
Storage itself has no Spark/free tier, which is the one piece of section 1
below that no longer applies once Blaze is active.

## 2) Push notifications (OneSignal + Cloudflare Worker)

1. Create OneSignal app, get:
   - OneSignal App ID
   - REST API key
2. Deploy worker template from `scripts/free_push_rollup_worker.js`.
   - Use `scripts/wrangler.toml.example` as your starting `wrangler.toml`.
3. Set worker secrets:
   - `WORKER_KEY`
   - `ONESIGNAL_REST_API_KEY`
4. Run app with:

```bash
flutter run \
  --dart-define=ONESIGNAL_APP_ID=your_onesignal_app_id \
  --dart-define=PUSH_WORKER_ENDPOINT=https://your-worker-domain/push \
  --dart-define=PUSH_WORKER_KEY=your_worker_key
```

The app stores `onesignalSubscriptionId` on:
- `users/{uid}`
- `families/{fid}/members/{uid}`

Chat/task actions then post to your worker which sends notifications via OneSignal.

## 3) Weekly rollups (free)

In-app manual generation is already available on:
- Leaderboard (`Run weekly rollup now`)
- Best Moments (`Generate now`)

Optional: wire a Cloudflare cron trigger (`wrangler.toml` `triggers.crons`) to
run weekly server-side jobs.

## Notes

- Firebase `functions deploy` remains optional on Spark.
- If defines are missing, free integrations remain no-op and UI falls back safely.

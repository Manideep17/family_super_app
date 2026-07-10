# Free Backend Setup (Spark + Cloudflare + OneSignal)

This app can run Blaze-like features without Firebase Blaze by combining Spark with free services.

## 1) Media uploads (Cloudinary free)

Create an unsigned upload preset in Cloudinary and run Flutter with:

```bash
flutter run \
  --dart-define=MEDIA_UPLOADS_ENABLED=true \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

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

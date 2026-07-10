# HTTPS invite links (App Links and Universal Links)

**Current priority:** Ship **Android App Links** (`assetlinks.json`). **iOS Universal Links are deferred** (no TestFlight/signing push right now)—the iOS steps below remain reference for when you reopen iOS.

FAM accepts invites from:

- Custom scheme: `famsuperapp://join/CODE`
- HTTPS (after you host verification files): `https://<your-host>/join/CODE`  
  Optional query: `?code=CODE` or `?join=CODE`

The app allowlist is in Dart: [`lib/core/config/invite_link_hosts.dart`](../lib/core/config/invite_link_hosts.dart).  
Default host is `invite.example.com` — **replace** it everywhere below and in:

- `--dart-define=INVITE_HTTPS_HOSTS=join.yourdomain.com`
- [`android/app/src/main/res/values/strings.xml`](../android/app/src/main/res/values/strings.xml) → `invite_https_host`
- [`ios/Runner/Runner.entitlements`](../ios/Runner/Runner.entitlements) → `applinks:invite.example.com`

Serve a simple redirect or static page at `https://<host>/join/CODE` if you want browser users without the app to see instructions; the app opens via verified links when installed.

## Android App Links (Digital Asset Links)

1. Use the same package name as the app: `com.family.superapp`.
2. Get your **release** signing certificate SHA-256 (see `docs/RELEASE_SIGNING.md`).
3. Host at **exactly**:

`https://<your-host>/.well-known/assetlinks.json`

Example (replace `YOUR_SHA256` and host):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.family.superapp",
      "sha256_cert_fingerprints": ["YOUR_SHA256"]
    }
  }
]
```

4. After deploy, verify:  
   `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://<your-host>&relation=delegate_permission/common.handle_all_urls`

The manifest uses `android:autoVerify="true"` on the HTTPS intent filter.

## iOS Universal Links (deferred)

When iOS shipping resumes:

1. Enable the **Associated Domains** capability in Xcode (the project includes `Runner.entitlements` with `applinks:invite.example.com` — update the domain).
2. Host at:

`https://<your-host>/.well-known/apple-app-site-association`

Example (replace `TEAMID` with your Apple Developer Team ID, bundle `com.family.superapp`):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.family.superapp",
        "paths": ["/join/*"]
      }
    ]
  }
}
```

No file extension; served with `Content-Type: application/json` (many hosts work with `text/plain` too).

## Testing

- **Android:** `adb shell am start -a android.intent.action.VIEW -d "https://invite.example.com/join/ABC123"` (use your host and a real 6-character code).
- **iOS** (when platform is active again): open the same URL in Notes or Safari on device.

See also [IOS_TESTER_EXPECTATIONS.md](IOS_TESTER_EXPECTATIONS.md) when iOS returns to scope.

Until verification files are live, the custom scheme link still works for in-family sharing.

# iOS testing expectations (FAM)

## What works today without a paid Apple Developer Program

- **Simulator**: Build and run from Xcode or `flutter run` targeting an iOS Simulator.
- **Physical device (USB)**: Install a **debug** or **ad hoc** build from Xcode onto a device you connect by cable, using your free or paid Apple ID for signing.

## What needs the Apple Developer Program ($)

- **TestFlight** builds for testers to install over the air.
- **App Store** distribution (when you are ready for public release).

## Invite links on iOS

- **Custom scheme**: `famsuperapp://join/CODE` — works once the app is installed; share from **My family** (app link button).
- **HTTPS Universal Links**: After you host `apple-app-site-association` on your domain, taps on `https://<your-host>/join/CODE` open the app when installed. Configure the domain in [`Runner.entitlements`](../ios/Runner/Runner.entitlements) and match [`InviteLinkHosts`](../lib/core/config/invite_link_hosts.dart). Full steps: [HTTPS_APP_LINKS.md](HTTPS_APP_LINKS.md).

## If testers ask “Why no TestFlight?”

Point them here: TestFlight is optional for early family testing; USB or Simulator builds are normal for beta apps that have not enrolled in the paid program yet.

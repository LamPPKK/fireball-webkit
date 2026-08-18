# Fireball Browser for WebKit

Fireball is a native SwiftUI browser shell around `WKWebView` for iOS and iPadOS 18+. WebKit remains responsible for page rendering and its sandboxed process model. The app does not rerender page content with Metal and includes no telemetry SDK.

Marketing version: `0.1.0` · Bundle identifier: `com.fireball.browser` · Default search: Brave Search

## Implemented beta foundation

- Stable UUID domain model for profiles, spaces, tabs, bookmarks and history.
- A profile owns the WebKit storage boundary; multiple spaces can share one profile.
- Persistent profiles use `WKWebsiteDataStore(forIdentifier:)`; private spaces use nonpersistent stores and are excluded from restore.
- Adaptive iPhone/iPad browser UI with a tab grid, space switcher, bottom omnibox, bookmarks, history and native home.
- Focused-scene iPad keyboard commands for tabs, omnibox and navigation, with a Dynamic Type-aware status rail and VoiceOver metadata.
- Confirm-before-open handling for `mailto:` and `tel:`; script, data, file and custom schemes are blocked.
- Background WebViews are released under memory pressure while tab state and snapshots remain available.
- `NSPersistentCloudKitContainer` local replica with private CloudKit metadata sync, 30-day deletion tombstones and opt-in 90-day history sync.
- Per-profile blocker and biometric controls, private-space foreground lock and app-switcher privacy cover.
- Signed, checksummed, sharded blocker manifest v1 with last-known-good rollback.
- English privacy/support pages, privacy manifest, app icon and protected TestFlight workflow.

The release workflow deliberately stops if CloudKit production schema promotion is not acknowledged, signing credentials are absent, or Apple does not accept ownership of `com.fireball.browser`. It never selects another identifier automatically.

## Build and test

```sh
xcodegen generate
FIREBALL_IPHONE_UDID="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 Tools/select_simulator.py --family iphone)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project FireballWebKit.xcodeproj \
  -scheme FireballWebKit \
  -destination "platform=iOS Simulator,id=$FIREBALL_IPHONE_UDID" \
  CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover -s Tools/tests
```

Debug and CI builds keep CloudKit and remote blocker downloads disabled so unsigned simulator tests remain deterministic. Release builds enable both through generated Info.plist flags.

## Blocker releases

`Blocker/sources.json` pins EasyList and EasyPrivacy to an exact upstream commit. `Tools/build_blocker.py` converts only the supported network-rule subset and emits an unsupported-rule report. The protected `blocker-rules` workflow checks that its Ed25519 private and public keys match, signs the canonical manifest, publishes immutable source/artifact provenance, and deploys stable GitHub Pages URLs.

Required protected secrets:

- `BLOCKER_SIGNING_KEY_BASE64`
- `BLOCKER_PUBLIC_KEY_BASE64`

EasyList/EasyPrivacy and derived artifacts retain GPL-3.0-or-later attribution. See [Blocker/README.md](Blocker/README.md).

## TestFlight setup

The `testflight` GitHub environment requires:

- secrets `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, and `BLOCKER_PUBLIC_KEY_BASE64`;
- environment variable `CLOUDKIT_SCHEMA_PROMOTED=true` only after the development schema has been promoted to production;
- manual approval before archive and upload.

Build numbers use the GitHub Actions run number. CI archives once, exports and validates that archive, then uploads the exact IPA without rebuilding.

External TestFlight acceptance, two-device iCloud validation, physical-device accessibility checks and Apple Beta App Review remain external release gates. Fireball Blink must not begin until those gates pass. XanhTab and fireball-docker remain frozen and are not modified by this roadmap.

Use the [external TestFlight gate checklist](Release/TESTFLIGHT.md) to record physical-device and App Review evidence for the exact uploaded IPA.

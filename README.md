# Fireball Browser for WebKit

[![CI](https://github.com/LamPPKK/fireball-webkit/actions/workflows/ci.yml/badge.svg)](https://github.com/LamPPKK/fireball-webkit/actions/workflows/ci.yml)
[![iOS 18+](https://img.shields.io/badge/iOS%20%2F%20iPadOS-18%2B-67F58A)](https://developer.apple.com/ios/)
[![Version](https://img.shields.io/badge/version-0.1.0-F58547)](Release/TESTFLIGHT.md)

Fireball is a native SwiftUI browser shell around `WKWebView` for iPhone and iPad. It keeps WebKit's sandboxed process model, separates website data by profile, leaves private spaces out of restore, and ships without a telemetry SDK.

![Fireball tab grid on iPad](docs/assets/fireball-ipad-tabs.png)

Marketing version `0.1.0` · Bundle identifier `com.fireball.browser` · Default search Brave Search · External TestFlight candidate

## Demo and screenshots

[▶ Watch the 10-second Simulator demo](docs/assets/fireball-demo.mp4)

| Native home | Tab grid | Privacy settings |
| --- | --- | --- |
| ![Fireball home on iPhone](docs/assets/fireball-iphone-home.png) | ![Fireball tab grid on iPhone](docs/assets/fireball-iphone-tabs.png) | ![Fireball settings on iPhone](docs/assets/fireball-iphone-settings.png) |

The screenshots were captured by `testCaptureDocumentationMedia`; the MP4 records that same UI-test flow in Simulator. These files are documentation evidence, not a substitute for physical-device or TestFlight acceptance.

## What is implemented

### Profiles, spaces, and tabs

- Stable UUIDs for profiles, spaces, tabs, bookmarks, and history visits.
- A profile owns one persistent `WKWebsiteDataStore(forIdentifier:)`; multiple spaces may share that profile.
- A private space uses `WKWebsiteDataStore.nonPersistent()` and never persists tabs, history, or snapshots.
- Adaptive iPhone tab grid and iPad sidebar/grid, swipe-to-close, popup-to-tab handling, native home, bookmarks, and history.
- Regular tab restoration after relaunch and LRU release of background WebViews under memory pressure.

### Browsing and resilience

- Bottom omnibox with Brave Search by default and DuckDuckGo, Google, or Bing per profile.
- Back, Forward, Reload, Home, bookmarks, native URL sharing, and focused-scene iPad keyboard commands.
- Only HTTP and HTTPS enter WebKit. `mailto:` and `tel:` require confirmation; script, data, file, and custom schemes are blocked.
- If WebKit terminates the active content process, Fireball retries once. A repeated failure stops the loop and tells the user to reload. A terminated background session is discarded and recreated only when needed.

### Privacy and sync

- Private CloudKit metadata sync through `NSPersistentCloudKitContainer` with a local replica, last-writer-wins UUID conflict handling, and 30-day tombstones.
- Profiles, spaces, regular tabs, bookmarks, and settings may sync; cookies, cache, credentials, biometric state, snapshots, and private tabs never do.
- History sync is opt-in, disclosed before enabling, and limited to 90 days.
- Per-profile signed content-blocker policy with last-known-good rollback.
- Optional profile lock through Keychain and LocalAuthentication, private-space foreground lock, and an app-switcher privacy cover.
- No proprietary telemetry SDK and no default analytics upload.

### Accessibility

- 48-point minimum controls, Dynamic Type-aware layouts, VoiceOver labels and actions, and iPad hardware-keyboard navigation.
- Automated accessibility audits cover browser chrome, tab grid, library, and settings on iPhone and iPad Simulator lanes.

## Midori reference audit

The latest GitHub state of [`midori-android`](https://github.com/LamPPKK/midori-android) and [`midori-core`](https://github.com/LamPPKK/midori-core) was reviewed as reference material, not copied as implementation instructions.

This pass adopted two compatible ideas: native URL sharing and explicit WebKit content-process recovery. It did not import Firefox Sync/password-vault code, the iOS 26 `WebPage` API, Android System WebView/WPE adapters, or the portable-backup format into the 0.1 beta.

The exact source commits, decision ledger, and post-beta candidates are recorded in [the Midori reference audit](docs/MIDORI_REFERENCE.md).

## Build and test

Requirements:

- macOS with Xcode 16 or newer and an iOS 18+ Simulator runtime.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46 or newer.
- Python 3 for release and blocker tooling tests.

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

Debug and CI builds keep CloudKit and remote blocker downloads disabled so unsigned Simulator tests remain deterministic. Release builds enable both through generated Info.plist flags.

## Blocker releases

`Blocker/sources.json` pins EasyList and EasyPrivacy to exact upstream commits. `Tools/build_blocker.py` converts the supported network-rule subset and emits an unsupported-rule report. The protected `blocker-rules` workflow verifies the Ed25519 key pair, signs the canonical manifest, and publishes immutable source and artifact provenance.

Required protected secrets:

- `BLOCKER_SIGNING_KEY_BASE64`
- `BLOCKER_PUBLIC_KEY_BASE64`

EasyList, EasyPrivacy, and derived artifacts retain GPL-3.0-or-later attribution. See [Blocker/README.md](Blocker/README.md).

## External TestFlight gate

The protected `testflight` environment requires:

- `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, and `BLOCKER_PUBLIC_KEY_BASE64`;
- `CLOUDKIT_SCHEMA_PROMOTED=true` only after the development schema is promoted to production;
- manual approval before archive and upload.

Release CI archives once, verifies the signature and production entitlements, exports once, inspects the exact IPA, records its SHA-256 checksum, validates it with App Store Connect, and uploads that same file without rebuilding.

External Beta App Review, two-device iCloud isolation, physical-device accessibility, IPv6-only, memory-pressure, and stability checks remain release gates. Follow [Release/TESTFLIGHT.md](Release/TESTFLIGHT.md) and attach evidence to the exact uploaded IPA.

Fireball Blink remains frozen until this gate passes. XanhTab and `fireball-docker` remain outside this roadmap except for urgent security fixes.

## Repository map

| Path | Responsibility |
| --- | --- |
| `App/` | SwiftUI shell, adaptive surfaces, commands, and app lifecycle |
| `Sources/Browser/` | `WKWebView` sessions, navigation, blocker application, recovery, and coordination |
| `Sources/Domain/` | Stable browser models, URL policy, and session restoration |
| `Sources/Persistence/` | Core Data and private CloudKit metadata replica |
| `Sources/Security/` | Keychain and LocalAuthentication boundaries |
| `Blocker/` | Signed blocker manifest schema, provenance, and bundled rules |
| `Tests/`, `UITests/` | Unit, integration, accessibility, and documentation-media tests |
| `Tools/` | Blocker, release, entitlement, IPA, and Simulator verification tools |
| `docs/` | GitHub Pages, screenshots, demo, and architecture notes |

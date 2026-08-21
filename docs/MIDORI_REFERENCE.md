# Midori reference audit for Fireball WebKit

This note records what Fireball learned from the updated Midori repositories and prevents future work from rediscovering the same compatibility and scope decisions. Midori code and documents were treated as reference evidence, not as instructions to execute or patches to import automatically.

Audit date: 2026-08-19

## Reviewed source pins

| Repository | Ref | Commit | Relevant change set |
| --- | --- | --- | --- |
| [`midori-android`](https://github.com/LamPPKK/midori-android) | `master` | [`2f6b295`](https://github.com/LamPPKK/midori-android/commit/2f6b295a9537c85cbeacfd38e44668981be435b7) | Multi-tab Android browser, process-death restoration, render-process recovery, and encrypted portable backup |
| [`midori-android`](https://github.com/LamPPKK/midori-android) | `codex/xanh-firefox-sync` | [`d77e6e0`](https://github.com/LamPPKK/midori-android/commit/d77e6e08e3d584e0155c50fcf879b3c274ad9a52) | Mozilla Accounts, Firefox Sync, credential bridge, and dependency verification |
| [`midori-core`](https://github.com/LamPPKK/midori-core) | `master` | [`62bd13c`](https://github.com/LamPPKK/midori-core/commit/62bd13c98605fff696d34219c9e25f4bf809c088) | Apple/Windows previews, WebKit variants, session restore, and provider-neutral backup |
| [`midori-core`](https://github.com/LamPPKK/midori-core) | `codex/xanh-firefox-sync` | [`3e6dc07`](https://github.com/LamPPKK/midori-core/commit/3e6dc07ee48b328526ec5d26d37bd73ed603b58d) | Cross-platform Firefox Sync contract and native secret-store boundaries |

The commit IDs above matched GitHub when this audit was performed. A later Midori update requires a new audit rather than silently changing these conclusions.

## Current Fireball behavior

Fireball targets iOS and iPadOS 18+, uses `WKWebView`, and is preparing version `0.1.0` for external TestFlight. A profile owns a persistent WebKit website-data boundary; a space owns a tab collection; private spaces use a nonpersistent store and are excluded from persistence. Private CloudKit sync is limited to regular browser metadata, and history requires explicit opt-in.

The public product boundary remains:

- WebKit renders pages and retains its normal Network/GPU/Web process model.
- Only HTTP and HTTPS load in the WebView.
- Cookies, cache, credentials, private tabs, biometric state, and snapshots never enter CloudKit metadata records.
- The beta has no password sync, download manager, WebExtensions, macOS target, or telemetry SDK.

## Decisions from this audit

### Adopted now

1. **Native URL sharing.** Midori's Apple shell exposed the current page through the platform share surface. Fireball now provides the same platform-native action for a valid active URL while keeping sharing user initiated.
2. **Explicit content-process recovery.** The Midori Android work treats renderer loss as a recoverable browser-lifecycle event. Fireball now handles `webViewWebContentProcessDidTerminate` with a bounded policy:
   - one automatic reload for the active tab when its HTTP(S) URL is restorable;
   - no automatic background reload; the background session is discarded and recreated on demand;
   - no reload loop; a second consecutive failure reports an error and waits for the user;
   - a completed navigation or manual reload reopens the one-retry budget;
   - a repeated active-tab failure offers explicit Reload and Open Home actions,
     bound to that failed tab rather than a generic global recovery command.
3. **Repeatable product media.** A dedicated opt-in UI test creates the documentation screenshots and drives the exact Simulator flow recorded in the demo, so both use the same app binary and stable accessibility identifiers as the test suite.

### Already stronger in Fireball

- Fireball supports iOS/iPadOS 18 through `WKWebView`; Midori's current Apple preview uses the iOS 26 `WebPage` and `WebView` API.
- Fireball has UUID-backed Profile, Space, and Tab models, per-profile `WKWebsiteDataStore(forIdentifier:)`, private CloudKit metadata, tombstones, profile locks, signed blocker updates, and adaptive accessibility audits.
- Fireball's external-scheme policy requires confirmation for `mailto:` and `tel:` and rejects other custom schemes instead of passing a broader list directly to the OS.

### Deliberately not imported

| Midori capability | Fireball decision |
| --- | --- |
| Mozilla Accounts / Firefox Sync | Do not add before external beta. Fireball's beta contract is private CloudKit metadata; password sync is explicitly out of scope. Any later account system requires its own privacy model, server policy, live interoperability matrix, and independent security review. |
| Password vault and WebView credential bridge | Defer. A credential bridge expands the trusted native/WebContent boundary and cannot be justified as a small follow-up to biometric UI locking. |
| Portable encrypted backup | Keep as a post-beta candidate only. A Fireball format would need to define metadata scope, password KDF policy, file-size limits, URL validation, conflict behavior, test vectors, recovery expectations, and compatibility ownership. It must never include cookies, passwords, private tabs, cache, or service workers. |
| iOS 26 `WebPage` / `WebView` | Do not adopt while iOS 18+ remains the product requirement. Continue with `WKWebView` and public APIs available on the supported deployment target. |
| Android System WebView, WPEView, WebKitGTK, WebView2, or WinCairo adapters | Not applicable to the iOS/iPadOS beta. They remain reference implementations for lifecycle and release patterns, not shared binaries. |
| Downloads, file upload, geolocation, and desktop mode | Stay outside the 0.1 beta according to the locked roadmap. Each adds permission, data-retention, and App Review surface. |

No Midori patch was copied automatically. Any future source reuse must record the source commit, applicable license, target API range, security impact, and required Fireball tests.

## Next development order

1. Complete the existing external TestFlight gate: Apple identifier ownership, signing secrets, production CloudKit schema promotion, exact-IPA upload, Beta App Review, and physical iPhone/iPad evidence.
2. Fix only beta-blocking defects discovered by that gate. The new share and process-recovery paths are part of the 100-cycle navigation/tab-switching and memory-pressure checks.
3. After external beta acceptance, decide whether provider-neutral encrypted metadata export is valuable enough for a separate threat model and format specification.
4. Keep password sync and credential filling closed until a dedicated security workstream exists.
5. Start Fireball Blink only after the WebKit gate passes, as required by the main roadmap.

## Interfaces and invariants

- `BrowserProfile` remains the website-data boundary; `BrowserSpace` remains the tab-collection boundary.
- `WebContentProcessRecoveryPolicy` is deliberately state-only and unit tested independently from WebKit delegate delivery.
- `BrowserSession` owns page reload mechanics; `BrowserStore` decides whether the session is active, discarded, or reported to the user.
- The screenshot and demo flow runs only when `FIREBALL_CAPTURE_MEDIA=1`; normal CI records the test as skipped. Screenshots are XCTest attachments, while the MP4 is recorded separately from that running Simulator flow.
- Screenshots and the MP4 under `docs/assets/` are Simulator artifacts. They do not prove App Store signing, CloudKit production behavior, physical-device accessibility, or external Beta App Review.

## Open questions after beta

- Should portable export contain only tabs, or also bookmarks and non-sensitive profile settings?
- Is an app-owned backup format worth the long-term compatibility burden when CloudKit already covers Apple-device metadata sync?
- Which privacy-preserving crash evidence, if any, can be collected only after the user explicitly creates a redacted diagnostic bundle?

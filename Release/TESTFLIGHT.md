# External TestFlight gate

Fireball WebKit does not unlock Blink development until every required row below has evidence from the exact uploaded `0.1.0` IPA. A local or CI simulator pass is not a substitute for Apple Beta App Review or physical-device checks.

## One-time Apple setup

- Register `com.fireball.browser`. Stop if Apple does not accept that exact identifier.
- Register `iCloud.com.fireball.browser` and enable CloudKit plus remote notifications.
- Create the App Store Connect app record and an API key with permission to upload builds.
- Exercise the CloudKit development schema, then promote that schema to production.
- Add the five protected secrets named in `README.md` to the `testflight` GitHub environment.
- Set `CLOUDKIT_SCHEMA_PROMOTED=true` only after promotion is complete.

The GitHub environment accepts deployments only from `main` and requires a manual review from `LamPPKK`. The workflow validates every release input before archiving and will not invent a fallback bundle identifier.

## Artifact chain

For each candidate, retain:

- Git commit and TestFlight workflow run URL.
- GitHub Actions build number.
- SHA-256 file emitted beside the IPA.
- `altool` validation and upload result.
- App Store Connect processing result and TestFlight build identifier.

The workflow archives once, verifies the distribution signature and production entitlements, exports once, checks bundle/version/build metadata, production flags, iPhone/iPad support, privacy declarations, the exact blocker public key and absence of packaged private-key files, records the IPA checksum, and uploads that same file.

## Required device evidence

Record pass/fail, device model, OS version, build number, tester, and evidence link for every row.

| Test | Required result |
| --- | --- |
| iPhone install/launch | Installs from TestFlight and reaches native home on iOS 18+ |
| iPad install/launch | Installs from TestFlight and adaptive sidebar/grid is usable on iPadOS 18+ |
| Two-device iCloud | Regular profiles, spaces, tabs, 30-day archived-tab metadata, bookmarks, and settings converge |
| Pinned tabs | Pin state persists and syncs, pinned tabs sort first, and automatic Archive never moves them |
| Automatic Archive | Off/1/7/30-day policies move only inactive regular background tabs; active, pinned, Home, and private tabs remain open |
| Cookie boundary | Website cookies do not appear in another profile or another device through Fireball sync |
| Private boundary | Private tabs, private Archive entries, history, snapshots, and restore state do not appear after relaunch or on device two |
| History opt-in | URL sync starts only after the disclosure is accepted; records older than 90 days disappear |
| Offline/reconnect | Browsing remains usable on the local replica and sync later recovers |
| iCloud account change | Browser remains usable and clearly reports degraded/local sync state |
| IPv6-only | Search, navigation, blocker update, and CloudKit sync remain functional |
| Memory pressure | Active tab survives; least-recent background WebViews restore on activation |
| Web content process loss | Active page automatically retries once; a repeated failure stops and reports; terminated background sessions restore only when activated |
| Biometric cancellation | Protected profile remains locked |
| Biometric-set change | Protected profile fails closed and device-owner recovery works |
| 100-cycle stability | 100 navigation, new-tab, switch, and close cycles produce no reproducible crash or data loss |
| VoiceOver | Browser controls, tab cards, spaces, privacy state, and destructive actions are named and ordered |
| Dynamic Type | Core controls remain reachable at accessibility sizes; the status rail collapses nonessential metadata |
| Automated audit | Browser chrome, tab grid, library and settings pass element descriptions, hit regions, Dynamic Type, text clipping, and trait checks in the iPhone and iPad CI lanes |
| Hardware keyboard | On iPad, verify Cmd-T, Cmd-W, Cmd-L, Cmd-R, Cmd-[, Cmd-], Cmd-Shift-\\ and Cmd-D; omnibox, navigation, tab grid, and settings remain reachable without touch |

## Go/no-go

The gate passes only after Apple Beta App Review accepts the build, every device row passes, and there is no open P0/P1 issue, reproducible data loss, or reproducible crash. Until then, keep `fireball-blink`, XanhTab, and `fireball-docker` frozen except for urgent security fixes.

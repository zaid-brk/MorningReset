# Screen Time feasibility

Research checked on 2026-10-03 against Apple's documentation. No real-device results have been recorded yet.

## Supported implementation

| Requirement | Implementation | Evidence / verification |
| --- | --- | --- |
| Individual authorization | `requestAuthorization(for: .individual)` | [Apple authorization documentation](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)) documents individual authorization. Device check pending. |
| Choose and shield selected apps | `FamilyActivityPicker`, persisted opaque application tokens, named `ManagedSettingsStore` | [Family Controls](https://developer.apple.com/documentation/familycontrols) and [Screen Time API updates](https://developer.apple.com/videos/play/wwdc2022/110336/) describe authorization and shared named stores. Device check pending. |
| Nightly shielding without the app | DeviceActivityMonitor extension applies shields at a reconciled nightly start | [DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor) describes extension callbacks and shield changes. Device check pending. |
| Survive relaunch | Persisted task snapshot, session phase, absolute task/wait deadlines | Tested in Foundation core through encode/decode and later reconciliation. App/device relaunch and reboot checks pending. |
| Ten-minute waiting period | Persist `finalConfirmationTime + 600 seconds`; release on next foreground reconciliation | Core timing and release gates tested. Device release pending. |

## Why foreground release is the default

Apple documents a [fifteen-minute minimum monitoring interval](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort). Therefore, simply scheduling a ten-minute DeviceActivity interval is unsupported.

We considered an interval with a longer duration and an end warning, as well as backdating its start. [DeviceActivitySchedule](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule) supports warning callbacks, but its documented behavior does not establish that either approach will execute an unlock at an exact ten-minute deadline while the app is suspended. In particular, Apple's [intervalDidEnd documentation](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:)) says delivery depends on device use. These alternatives have not been proven on hardware and are not used as an automatic-release claim.

An ordinary main-app timer cannot keep running after suspension or termination. A local notification can alert the person; it cannot act as a scheduled executor for ManagedSettings. No background refresh requests are used as an exact deadline mechanism.

The implemented, labeled fallback retains the ten-minute product deadline: an optional expiry reminder asks the user to open Morning Reset, and the app then releases that session's restriction if its deadline elapsed and no newer night superseded it. The waiting UI and README both describe this behavior. The restriction may last longer if the user does not return. This is a conservative implementation decision, not a proof that no future supported automatic mechanism could exist.

## Prototype and evidence collection

In Settings, **Screen Time feasibility checks** exposes real manual shielding and release, separate from normal nightly scheduling. Prototype periods have a flag that excludes them from protected streaks. Demo sessions apply no simulated or real restrictions and also earn no protected streak.

Begin with one selected distracting app, test manual shield/release, then set tonight a few minutes ahead and terminate the main app. Inspect the protected app at/after the scheduled time. Record iPhone model, iOS version, build number, signing type, time, whether the phone was in use, and any shared diagnostic callbacks.

Use [VALIDATION.md](VALIDATION.md) for the full matrix. Until these checks are completed, a successfully registered schedule means registration succeeded; it is not a claim that a callback was physically observed.

## Distribution

[Apple's Family Controls entitlement process](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) requires distribution approval for the app and its relevant Screen Time extensions. Development entitlements are included in the source project, but actual provisioning still depends on the developer account. No distribution approval, TestFlight upload, or App Store submission is claimed.

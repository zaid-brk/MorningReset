# Morning Reset

A native iPhone app that gives your morning a little room before the scroll. Choose distracting apps and a nightly lock time, complete a short routine of timed, self-confirmed tasks, then take a ten-minute pause.

SwiftUI · iOS 17+ · Screen Time APIs · local storage · no account or backend

Source backup: [zaid-brk/MorningReset](https://github.com/zaid-brk/MorningReset) (private repository). Local signing settings are excluded; a fresh clone needs its own `Config/Local.xcconfig`.

**Current release behavior:** after ten minutes, reopen Morning Reset to release the selected apps. The optional notification reminds you to return; it does not execute an unlock. This is the explicitly labeled fallback from the specification, not a claim of automatic background release. See [feasibility evidence](Docs/FEASIBILITY.md).

## What is included

- Five-step onboarding and Today, Routine, and Settings tabs.
- Individual Screen Time authorization, Apple's app picker, a named ManagedSettings shield store, a DeviceActivity monitor extension, and a shield appearance extension.
- Daily nightly scheduling and a one-night time adjustment. Selected individual apps only; no device-wide restrictions.
- Editable presets and custom tasks, deletion and reordering, a 15-second minimum, and session snapshots.
- Sequential, manually started countdowns and manually confirmed completion. Saved timestamps survive relaunch and restart.
- A ten-minute waiting deadline, optional task/wait reminders, and a confirmed bypass option.
- Current/best routine streaks, successful mornings this week, and local history. Demo/prototype sessions never earn protected streak credit.
- Warm light and charcoal dark themes, system typography, accessible controls, and a vector-drawn sunrise icon.
- A separate **MorningResetDemo** scheme for free Personal Team testing, with routine timers, waiting, reminders, and history; no app blocking or protected streak credit.

**Validation status:** All 26 core test cases passed with both the Swift command-line runner and actual XCTest using the installed Xcode toolchain. With Xcode 27.0, both the standalone demo and the full app with its extensions compiled successfully for a generic iOS device in unsigned builds. Neither edition has yet run on an iPhone. Actual authorization, picker, shielding, callbacks, notifications, SwiftData persistence, and accessibility/layout still require device checks. See [validation record](Docs/VALIDATION.md).

## Run the free demo on your iPhone

1. Open `MorningReset.xcodeproj` in **Xcode on your Mac**. Select **MorningResetDemo** in the scheme menu at the top.
2. Sign in under **Xcode → Settings → Apple Accounts**. The demo uses your **Personal Team** and automatic signing. In this workspace, the selected team and a unique bundle ID are already saved in the ignored `Config/Local.xcconfig`. For another checkout, copy the example config and enter your own team and unique base bundle ID.
3. Connect your iPhone, unlock it, and accept **Trust This Computer** if asked. Choose your iPhone in the destination menu beside the scheme, then press **⌘R**. Follow iOS's Developer Mode prompt if one appears.
4. The installed app is named **Morning Reset Demo**. Complete its short onboarding, edit the routine, and tap **I'm awake**. For a quick first check, use one 15-second task. The final confirmation starts the real ten-minute wait; reopen the app after the deadline to finish the session.

This build has no Screen Time entitlement, App Group, or embedded extensions. It stores its own local data, leaves other apps available, and never earns protected streak credit. Its saved nightly time is only a preview. The full app remains a separate scheme and installation.

## Run the full Screen Time app on your iPhone

1. Install the current stable **Xcode** from Apple, launch it, and complete its first-run setup and iOS platform download. Set its command-line tools under **Xcode → Settings → Locations**. Check `xcodebuild -version` from Terminal.
2. Open `MorningReset.xcodeproj`. Select the shared **MorningReset** scheme.
3. In **Xcode → Settings → Apple Accounts**, sign in to your Apple account. **The full Screen Time app requires an Apple Developer Program team; a free Personal Team cannot provision this configuration.** Apple documents Family Controls development access through the [Apple Developer Program](https://developer.apple.com/documentation/xcode/configuring-family-controls). [Membership costs 99 USD per year](https://developer.apple.com/programs/enroll/) in the United States. Use the free demo above to review routine UI first.
4. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`. Replace the example team, base bundle ID, and App Group with your own registered values. This local file is ignored by Git. Do not commit signing credentials.
5. In **Signing & Capabilities**, check **MorningReset**, **ActivityMonitor**, and **ShieldConfiguration**. All three must use the same team, have **Family Controls** and **App Groups**, and select the same registered App Group. Extension bundle IDs must begin with the app's bundle ID. If Xcode cannot provision a capability, resolve that in your developer account; a source entitlement alone does not grant access.
6. Connect and trust your iPhone. Enable **Developer Mode** if iOS requests it. Select the iPhone as the run destination, then press **⌘R**.
7. In onboarding, authorize Screen Time, expand categories and select one individual distracting app, set the nightly time, **enable the nightly schedule**, keep a short routine, and optionally enable notifications.
8. First run **Settings → Screen Time feasibility checks**. Verify manual shielding/release, then scheduled shielding with Morning Reset terminated. Complete the checklist in [Docs/VALIDATION.md](Docs/VALIDATION.md) before calling protection verified.

For a short routine test, use one 15-second task. The waiting period remains ten minutes in every mode. To test a lock soon, adjust tonight to a few minutes ahead. Do not expect an app that is suspended to execute its own countdown.

The simulator can help review UI and run core tests; it is not evidence of real Screen Time behavior. The in-app **demo** runs real routine logic but applies no shields and awards no protected streak. **Prototype** controls apply actual shields and also award no protected streak.

## Tests and project maintenance

With Swift Command Line Tools (including this environment):

```sh
python3 Scripts/test_core.py
python3 Scripts/check_project.py
```

The command-line runner compiles the same test methods used by XCTest with a small assertion adapter. It tests real core code, including concurrent file transactions; it does not simulate the Screen Time frameworks.

With full Xcode selected:

```sh
swift test --scratch-path /tmp/morning-reset-build
xcodebuild -list -project MorningReset.xcodeproj
xcodebuild -project MorningReset.xcodeproj -scheme MorningReset \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/morning-reset-ios-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MorningReset.xcodeproj -scheme MorningResetDemo \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/morning-reset-demo-build CODE_SIGNING_ALLOWED=NO build
```

For the app-hosted XCTest target, choose an installed iPhone simulator from `xcrun simctl list devices available`, then run:

```sh
xcodebuild -project MorningReset.xcodeproj -scheme MorningReset \
  -destination 'platform=iOS Simulator,name=YOUR_INSTALLED_IPHONE_SIMULATOR' \
  -derivedDataPath /tmp/morning-reset-ios-tests CODE_SIGNING_ALLOWED=NO test
```

Regenerate the committed project after adding files:

```sh
python3 Scripts/generate_project.py
```

This deterministic generator uses Python's standard library; XcodeGen/CocoaPods are not required. Personal signing settings belong in the ignored local config, so generation preserves them. To regenerate the icon on macOS, run `swift Scripts/render_icon.swift`.

## Architecture

| Location | Responsibility |
| --- | --- |
| `Sources/MorningResetCore` | Session state machine, calendar/streak rules, injectable clock, locked atomic JSON storage |
| `MorningReset/App` | Observable app model and native app entry point |
| `MorningReset/Views` | Onboarding, three tabs, task editor, countdown, history, device prototype controls |
| `MorningReset/Services` | Screen Time integration, serialized reminders, main-app SwiftData history mirror |
| `Extensions/ActivityMonitor` | Begin/reconcile nightly protection without the main app running |
| `Extensions/ShieldConfiguration` | Native shield appearance within Apple's customization limits |

The shared App Group file is authoritative for the routine, active session, protection period, and history. A cross-process file lock serializes app/extension mutations. State is atomically saved before shield changes are applied, while still holding the lock. The extension never opens SwiftData. SwiftData mirrors completed history inside the main app; a mirror error never deletes shared history. See [architecture and calendar policies](Docs/ARCHITECTURE.md).

The standalone demo compiles with `MORNING_RESET_DEMO`, excludes the real Screen Time bridge, and uses its own Application Support directory instead of the App Group. It shares the routine engine and SwiftUI views while skipping protection onboarding and controls.

## Platform limitations and TestFlight preparation

- Release uses foreground reconciliation after the ten-minute deadline. It never uses a ten-minute DeviceActivity monitoring interval or assumes notifications can run code.
- DeviceActivity callbacks are delivered by iOS. Registration is reported separately from applied shields; actual timing must be checked on physical hardware. Revoked Screen Time access means protection is inactive.
- A reboot retains saved state, but the shared file is available only after the device's first unlock. ManagedSettings persistence and callbacks across reboot need device validation.
- Individual authorization is voluntary and bypassable. Activity completion is self-confirmed, and changing the system clock can affect wall-clock deadlines.
- The daily schedule and one-night adjustment are implemented. Separate weekday/weekend schedules are deferred to keep version one simple.

Before TestFlight/App Store distribution, request Apple's **Family Controls distribution approval for the app and relevant extension identifiers**; confirm the resulting provisioning support and profiles. [Apple's entitlement instructions](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) explain this requirement. Check all three signed targets, run the physical-device matrix, verify privacy declarations against the final app, update version/build numbers, and archive using the shared scheme. No TestFlight/App Store upload, submission, or public repository creation has been performed.

The original brief is preserved in `Morning-Reset-Codex-Prompt.md` and copied to [SPEC.md](SPEC.md). Project guidance is in [AGENTS.md](AGENTS.md).

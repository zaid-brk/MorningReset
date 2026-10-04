# Morning Reset

A native iPhone app that gives your morning a little room before the scroll. Choose distracting apps and a nightly lock time, complete a short routine of timed, self-confirmed tasks, then take a ten-minute pause.

SwiftUI · iOS 17+ · Screen Time or voluntary Shortcuts redirects · local storage · no account or backend

Source repository: [zaid-brk/MorningReset](https://github.com/zaid-brk/MorningReset). Local signing settings are excluded; a fresh clone needs its own `Config/Local.xcconfig`.

**Choose an edition:** `MorningResetShortcuts` uses a one-time, user-created Shortcuts automation to interrupt scrolling without the Family Controls entitlement. `MorningReset` uses real Screen Time shields and requires the appropriate developer team and entitlements. `MorningResetDemo` only demonstrates routines and never redirects or shields apps.

**Screen Time release behavior:** after ten minutes, reopen Morning Reset to release the selected apps. The optional notification reminds you to return; it does not execute an unlock. This is the explicitly labeled fallback from the specification, not a claim of automatic background release. The Shortcuts edition checks the saved deadline each time its automation runs and returns No after the wait, unless a newer night has started. See [feasibility evidence](Docs/FEASIBILITY.md).

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
- A separate **MorningResetShortcuts** scheme with a Boolean App Intent, nightly redirect periods, a seven-step onboarding/Settings tutorial, a 60-second setup test, and voluntary bypass. It has no Screen Time entitlement, App Group, or embedded extensions. Its routines never earn protected streak credit.

**Validation status:** All 35 core test cases passed with both the Swift command-line runner and actual XCTest. With Xcode 27.0, all three app editions compile for generic iOS hardware in unsigned builds, including App Intents metadata extraction for the Shortcuts action. Signing, installation, real automation execution/redirect latency, notifications, SwiftData persistence, and accessibility/layout still require device checks. See [validation record](Docs/VALIDATION.md).

## Run the Shortcuts edition on your iPhone

1. Open `MorningReset.xcodeproj` in Xcode and select **MorningResetShortcuts**. Use your Personal Team and the ignored `Config/Local.xcconfig`; a fresh checkout needs its own local config with a team and unique base bundle ID.
2. Connect and trust your iPhone, enable Developer Mode if requested, choose it as the destination, and press **⌘R**. The installed app is named **Morning Reset Shortcuts** and has independent data from both other editions.
3. In onboarding, choose **Start step-by-step tutorial**. The same guide is always available at **Settings → App redirects → Step-by-step setup & test**.
4. In Apple's Shortcuts app, create one **App → Is Opened → Run Immediately** personal automation. Choose all distracting apps together; exclude **Morning Reset Shortcuts** and **Shortcuts** to avoid loops.
5. Add **Check Morning Redirect** from this app. Below it, add **If**, using the action's Boolean output with condition **true/Yes**. Inside that branch add **Open App → Morning Reset Shortcuts**. Leave Otherwise empty. Save the automation. The tutorial explains variable selection and action placement.
6. Return to the last tutorial step and start the **60-second redirect test**. Open a selected app and check that it returns you here. After the check action ran, select **I saw the redirect · finish setup** only if you observed the return. Setup status is your report, not automatic verification.
7. Save your recurring nightly redirect time, edit your routine, optionally enable reminders, and finish onboarding. Redirects begin at the next nightly time, or when you tap **I'm awake** to start a routine. Complete each task and the ten-minute pause. The next automation check after the deadline allows the other app; a newer nightly period wins over an old wait.

The app cannot create or inspect personal automations. Configure once per device; revisit Shortcuts to edit the selected apps, repair a deleted automation, or set up a new phone. If Shortcuts is missing, install Apple's Shortcuts app. Apple's [app-trigger guide](https://support.apple.com/guide/shortcuts/setting-triggers-apde31e9638b/ios), [automation setup](https://support.apple.com/guide/shortcuts/apdfbdbd7123/ios), and [automatic execution settings](https://support.apple.com/guide/shortcuts/apd602971e63/ios) describe the supported workflow.

This is an interruption, not a system app lock. The selected app may appear briefly, an already-open app is not closed at the nightly time, and the user can disable the automation or use the in-app bypass. Shortcuts timing/reliability must be tested on a real iPhone. Free Personal Team provisioning expires after seven days; rebuild expired installations through Xcode and recheck the action. This development route does not provide App Store/TestFlight distribution. See [Apple's account limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

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

## Development workflow

Every change starts on a new branch from the latest `main`, including features, fixes, documentation, and configuration. Push the branch and open a pull request describing the change and relevant validation. Keep `main` free of direct pushes.

The project owner must explicitly confirm before a pull request is merged. A request to implement a feature does not authorize its merge. Do not enable auto-merge; address review feedback on the same branch and present the updated result for approval.

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
xcodebuild -project MorningReset.xcodeproj -scheme MorningResetShortcuts \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/morning-reset-shortcuts-build CODE_SIGNING_ALLOWED=NO build
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
| `Sources/MorningResetCore` | Session state machine, calendar/streak and voluntary redirect rules, injectable clock, locked atomic JSON storage |
| `MorningReset/App` | Observable app model and native app entry point |
| `MorningReset/Views` | Onboarding, three tabs, task editor, countdown, history, device prototype controls |
| `MorningReset/Services` | Screen Time integration, Shortcuts App Intent, serialized reminders, main-app SwiftData history mirror |
| `Extensions/ActivityMonitor` | Begin/reconcile nightly protection without the main app running |
| `Extensions/ShieldConfiguration` | Native shield appearance within Apple's customization limits |

The shared App Group file is authoritative for the routine, active session, protection period, and history. A cross-process file lock serializes app/extension mutations. State is atomically saved before shield changes are applied, while still holding the lock. The extension never opens SwiftData. SwiftData mirrors completed history inside the main app; a mirror error never deletes shared history. See [architecture and calendar policies](Docs/ARCHITECTURE.md).

The standalone demo compiles with `MORNING_RESET_DEMO`, excludes the real Screen Time bridge, and uses its own Application Support directory instead of the App Group. It shares the routine engine and SwiftUI views while skipping protection onboarding and controls.

The independent Shortcuts edition compiles with `MORNING_RESET_SHORTCUTS` and shares the demo's Screen Time isolation. Its App Intent reads and reconciles the same local JSON under the file lock; it does not construct UI or open the SwiftData mirror. A separate redirect-period UUID prevents an old routine from ending a newer night. Intent check failures throw an error rather than pretending a successful check. The app cannot guarantee interception if Shortcuts fails to run.

## Platform limitations and TestFlight preparation

- Release uses foreground reconciliation after the ten-minute deadline. It never uses a ten-minute DeviceActivity monitoring interval or assumes notifications can run code.
- DeviceActivity callbacks are delivered by iOS. Registration is reported separately from applied shields; actual timing must be checked on physical hardware. Revoked Screen Time access means protection is inactive.
- A reboot retains saved state, but the shared file is available only after the device's first unlock. ManagedSettings persistence and callbacks across reboot need device validation.
- Individual authorization is voluntary and bypassable. Activity completion is self-confirmed, and changing the system clock can affect wall-clock deadlines.
- The daily schedule and one-night adjustment are implemented. Separate weekday/weekend schedules are deferred to keep version one simple.

Before TestFlight/App Store distribution, request Apple's **Family Controls distribution approval for the app and relevant extension identifiers**; confirm the resulting provisioning support and profiles. [Apple's entitlement instructions](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) explain this requirement. Check all three signed targets, run the physical-device matrix, verify privacy declarations against the final app, update version/build numbers, and archive using the shared scheme. No TestFlight/App Store upload or submission has been performed.

The original brief is preserved in `Morning-Reset-Codex-Prompt.md` and at the beginning of [SPEC.md](SPEC.md), followed by the approved Shortcuts amendment. Project guidance is in [AGENTS.md](AGENTS.md).

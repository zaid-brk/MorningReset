# Validation record

## Verified in this workspace

- Original specification preserved; `SPEC.md` is a copy.
- Swift 6.2.4 command-line compiler on arm64 macOS compiled the Foundation core.
- **26 test cases passed**, using `python3 Scripts/test_core.py` and the same methods provided to XCTest.
- `python3 Scripts/check_project.py` passed: four targets, all 17 Swift source files parsed, file references, target membership, entitlements, plists, asset metadata, and shared scheme checked. `plutil` accepted the generated Xcode project. These checks do not type-check the iOS SDK APIs.
- Generated and visually checked the 1024×1024 sunrise icon; PNG has no alpha channel.

## Xcode follow-up — 2026-10-03

The user installed **Xcode 27.0, build 27A266a**, and opened the project. The app, ActivityMonitor, and ShieldConfiguration targets now **compile successfully for generic iOS hardware**, with signing disabled for this compiler check:

```sh
xcodebuild -project MorningReset.xcodeproj -scheme MorningReset \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/morning-reset-ios-build CODE_SIGNING_ALLOWED=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox' build
```

Result: **BUILD SUCCEEDED**. The command-only Swift flag allows Apple's compiler macro subprocesses to run inside the agent's existing restricted execution environment; it is not saved in the project and is not required for normal Xcode use. The first command without this flag failed because a nested compiler-plugin sandbox could not launch. This check validates iOS SDK compilation and linking, not signing, installation, or runtime behavior. Build log: `/tmp/morning-reset-ios-build.log`.

The user subsequently signed in and reported a **Personal Team**, then authorized a separate free demo. This free signing team cannot provision the full Screen Time configuration. Apple's [Family Controls setup documentation](https://developer.apple.com/documentation/xcode/configuring-family-controls) describes development access through the Apple Developer Program.

### Standalone demo — 2026-10-03

- Added the `MorningResetDemo` target and shared scheme without Screen Time frameworks, entitlements, App Group metadata, or extension dependencies. Updated onboarding/settings/copy and forced demo-only sessions. Personal signing settings were preserved in the ignored local config.
- `python3 Scripts/check_project.py` passed for **five targets and 19 Swift source files**, including demo isolation checks. The earlier four-target/17-file check above records the initial project.
- The demo **compiled and linked successfully** with the command above using `-scheme MorningResetDemo` and `-derivedDataPath /tmp/morning-reset-demo-build`. Log: `/tmp/morning-reset-demo-build.log`.
- Rebuilt the full `MorningReset` scheme after the shared-view changes: **BUILD SUCCEEDED**.
- Inspected the demo executable's linked libraries: no FamilyControls, ManagedSettings, or DeviceActivity frameworks. Its built app has no `PlugIns` directory or App Group Info.plist value and displays the name **Morning Reset Demo**.
- Selected **MorningResetDemo** in the user's open Xcode window and verified the toolbar's active scheme. Signing, installation, and UI execution remain pending on the iPhone.

The core was also retested with the installed Xcode toolchain using actual XCTest (`xcrun swift test`, with scratch/cache directories under `/tmp`). **All 26 XCTest tests passed, zero failures.** This is a macOS Foundation-core test run, not an iPhone runtime test. Log: `/tmp/morning-reset-xcode-core-tests.log`.
- Tests cover 15-second minimum/early completion, explicit sequential starts, delayed confirmations, task snapshot isolation, ten-minute deadline/release gates, Codable relaunch persistence, bypass after expiry, demo/prototype exclusions, new-night precedence, observed permission revocation, empty routine/missing shield rejection, midnight date attribution, once-per-day credit, tonight overrides, spring/fall DST, travel date preservation, current/best/week streaks, duplicate days, atomic persistence, corrupt-file handling, concurrent updates, failed transactions, retired-monitor callbacks, schedule changes, and state persistence before restriction side effects.

## Shortcuts edition — 2026-10-03

Implemented on `feat/shortcuts-redirect`, branched from the latest remote `main` (`f2601dec2c4fe763f8f94b5d9eb0784ea2f99ed5`). The Desktop workspace has no Git metadata; changes were made in a clean temporary checkout and copied back without local signing settings or Xcode user data.

Verified:

- `python3 Scripts/test_core.py`: **35 test cases, zero assertion failures**.
- Actual Foundation XCTest: **35 tests, zero failures**, using `CLANG_MODULE_CACHE_PATH=/tmp/morning-reset-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/morning-reset-xcode-swift-cache xcrun swift test --disable-sandbox --scratch-path /tmp/morning-reset-xcode-core-build --cache-path /tmp/morning-reset-package-cache --config-path /tmp/morning-reset-package-config --security-path /tmp/morning-reset-package-security`. Log: `/tmp/morning-reset-xcode-core-tests.log`. The first attempt needed its module cache redirected to a writable directory; the final run passed. This is macOS core testing, not an iPhone test.
- `python3 Scripts/generate_project.py` and `python3 Scripts/check_project.py`: **six targets, 22 Swift source files**, all references/metadata/schemes and syntax accepted. Demo and Shortcuts target checks confirm no Screen Time framework linkage, signing entitlement setting, App Group metadata, or embedded-extension dependency.
- **All three unsigned generic iOS builds succeeded** using the earlier Xcode command with `-scheme MorningResetShortcuts`, `MorningResetDemo`, and `MorningReset`. Logs: `/tmp/morning-reset-shortcuts-build.log`, `/tmp/morning-reset-demo-build.log`, `/tmp/morning-reset-ios-build.log`.
- The Shortcuts build generated `Metadata.appintents/extract.actionsdata` with discoverable `CheckMorningRedirectIntent`, Boolean output, `openAppWhenRun: false`, and no required capabilities; it also generated the App Shortcut phrase metadata.
- Inspected the built Shortcuts app and debug library: display name **Morning Reset Shortcuts**, no `MorningResetAppGroup` key, no `PlugIns` directory, no FamilyControls/ManagedSettings/DeviceActivity linkage, and AppIntents linked. The demo remains a separate target without these redirect intents.
- Nine additional core cases cover: no retroactive redirect on setup; nightly start and persistence across midnight; on-demand ten-minute completion without protected credit; newer-night precedence; explicit bypass at expired waits; a pre-onboarding 60-second setup test; pause/resume without timer reset; Codable relaunch/old-schema compatibility; active-period preservation on schedule edits; and DST/travel behavior.

Not verified: signed Personal Team installation, App Intent discovery or local-sandbox access at runtime, actual Shortcuts If/Open App execution, redirect delay, UI layout/accessibility, notifications, or SwiftData runtime persistence. `simctl` could not connect to CoreSimulator in this restricted environment; no simulator or physical-iPhone runtime result is claimed. The installed Xcode toolchain emitted the existing NotificationService delegate actor-isolation warning under Swift 5 mode; builds passed. A future Swift 6 migration must address that warning.

Physical Shortcuts checklist (record phone/iOS version and results):

| Check | Expected result | Result |
| --- | --- | --- |
| Install `MorningResetShortcuts` with Personal Team | No Screen Time or App Group provisioning required; independent app/data | Pending |
| First onboarding and Settings guide | Seven readable steps, saved place, multi-app selection and loop prevention | Pending |
| Discover Check Morning Redirect | Action appears under this app; returns a Boolean without foregrounding it | Pending |
| 60-second setup test | Selected app redirects back to guide; test expires without enabling nightly periods | Pending |
| Confirm observed test and finish onboarding | Status says user-confirmed; nightly redirects enabled, no claim of verified automation | Pending |
| Selected app before/after nightly time | Allowed before due; next app-opening check requests redirect after due | Pending |
| Start routine, leave app during each task | Redirect returns to Today/current task; timer survives relaunch; confirmation stays manual | Pending |
| Before/at ten-minute expiry with app closed | Redirect before deadline; after deadline no redirect unless a newer night applies | Pending |
| Bypass and next night | Current period ends without credit; next due night requests redirects | Pending |
| New night during an old routine/wait | Old routine interrupted; old deadline cannot end the newer period | Pending |
| Pause/resume, schedule edits, DST/travel | Saved state follows documented policies; no reset of task deadlines | Pending |
| Disable/delete automation, expired free provisioning | App does not falsely claim a verified connection; guide explains repair/rebuild | Pending |
| App already foreground at nightly time | No claim of forcibly closing that app | Pending |
| Reboot, offline, reminders declined | After first unlock, local checks/routines work; notifications never execute unlocks | Pending |
| Large text, light/dark, VoiceOver, Reduce Motion | Guide and routine readable/usable; no clipped steps | Pending |

### Tutorial clarity follow-up — 2026-10-04

The user reached the iPhone Shortcuts automation-trigger list but could not identify what to tap from tutorial step 2. Updated the seven-step guide with numbered, literal tap instructions and a visible App-row example. Step 2 locates App between CarPlay and Wallet in the supplied screenshots, explains the Weather placeholder, offers the Search field as a fallback, and walks through Choose → select apps → Done. Every step describes the expected next screen. Existing saved page indexes and the setup test remain unchanged.

Checked Apple's [App-trigger documentation](https://support.apple.com/guide/shortcuts/setting-triggers-apde31e9638b/ios) against the supplied screenshots. `python3 Scripts/check_project.py` and `git diff --check` passed. The unsigned generic iOS `MorningResetShortcuts` build succeeded; log: `/tmp/morning-reset-tutorial-build.log`. The existing NotificationService actor-isolation warning remains. No core behavior changed, so core tests were not repeated. Actual tutorial layout, Dynamic Type, VoiceOver, and whether the instructions resolve the user's confusion still require an iPhone check; simulator runtime access remains unavailable.

## Not yet verified

During initial implementation, this environment had Swift Command Line Tools, no Xcode app/iOS SDK, and no XCTest framework. That initial `swift test` attempt could not import XCTest; the command-line adapter executed the same tests. Xcode is now installed, and the iOS compiler check above succeeded.

The SwiftUI app, SwiftData mirror, and Screen Time targets have compiled and linked. Native UI layout, entitlements/signing, actual SwiftData persistence, and real iPhone behavior have **not been run or verified**. Physical tests must be performed after setup in README.md.

## GitHub source backup — 2026-10-03

Uploaded the source to the private [zaid-brk/MorningReset](https://github.com/zaid-brk/MorningReset) repository on `main`. The source snapshot excludes local signing configuration, personal team identifiers, Xcode user data, build products, and signing credentials. Project structure checks passed before upload. The current working directory does not contain Git metadata because the workspace denies creation of its `.git` directory; the upload used a temporary clean checkout. A fresh clone needs a local signing configuration before iPhone installation.

## Physical-device checklist

Record device model, iOS version, app build, signing method, local time zone, and results for every case. Test a development build first, then repeat the core shield/callback cases on a distribution build before TestFlight release.

For the standalone demo, first verify Personal Team installation, onboarding without Screen Time prompts, editing/starting/confirming tasks, relaunch during a task and wait, reminders, ten-minute completion, and local history. Other apps must remain available and protected streaks must remain zero. Shield/authorization/schedule cases below apply to the full scheme.

| Check | Expected result | Result |
| --- | --- | --- |
| Individual authorization granted | Status becomes available, native picker enabled | Pending |
| Authorization declined | Clear inactive state; demo remains usable | Pending |
| Select one individual app | Only that app is shielded; unrelated apps remain usable | Pending |
| Manual prototype shield/release | Actual system shield appears/disappears; no streak credit | Pending |
| Native shield | Calm appearance, button closes app, no claim it opens Morning Reset automatically | Pending |
| Scheduled lock with app backgrounded | Selected app becomes shielded; extension diagnostic recorded | Pending |
| Scheduled lock with app terminated | Same result without main-app execution | Pending |
| Lock over midnight | Shield persists; interval end never releases it | Pending |
| Background during a running task | Remaining time derived from saved deadline; no reset | Pending |
| Terminate/relaunch during task | Task and index preserved; expired timer awaits confirmation | Pending |
| Delay confirmation | Next timer waits for its own Start action | Pending |
| Finish all tasks | Wait deadline is exactly ten minutes after final confirmation | Pending |
| Background/terminate during wait | No automatic-release claim; shield stays until return | Pending |
| Return before deadline | Shield stays active | Pending |
| Return after deadline | Matching period released once; eligible session credited once | Pending |
| Notifications declined | Timers/routine/release continue to work | Pending |
| Task notification | Invites confirmation; never auto-completes task | Pending |
| Wait notification | Asks user to reopen app; never says already unlocked | Pending |
| Bypass during task/wait | Confirmed release, bypass history, no success credit | Pending |
| New night during task/wait | Old session interrupted; new period stays shielded | Pending |
| Old wait notification after a new night | Foreground retains new period; no stale unlock | Pending |
| Edit template during session | Active snapshot unchanged; next session uses edits | Pending |
| Revoke Screen Time access | Settings/Today show inactive; observed session loses protected credit | Pending |
| Replace/remove selected apps mid-session | No protected streak credit for that session | Pending |
| Tonight override earlier/later than usual | Only effective lock applies; tomorrow uses usual time | Pending |
| Change/disable schedule during protection | Current shield stays until completion/bypass | Pending |
| Reboot during task/wait | After first device unlock, saved state reconciles correctly | Pending |
| Change time zone / DST transition | Core date policy matches device behavior; schedule follows local time | Pending |
| Light/dark, large text, VoiceOver, Reduce Motion | Legible layout and labels; usable task controls | Pending |
| Airplane mode | Routine/history usable without a network or account | Pending |

## After installing Xcode

Run the exact build/test commands in README.md. Resolve any SDK type or signing errors before calling the app buildable on your machine. Record compiler, Xcode version, destination, commands, and outcomes here. For shielding/callback issues, inspect device Console logs for MorningReset/Monitor and the shared diagnostic list in Settings. A registered monitor alone is not evidence of callback delivery.

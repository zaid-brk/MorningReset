# Morning Reset

A native iPhone app that gives your morning a little room before the scroll. Set a nightly time, complete a short routine of timed, self-confirmed tasks, then take a ten-minute pause before returning to your distracting apps.

**Install the `MorningResetShortcuts` edition using the tutorial below.** It uses Apple's Shortcuts app to send you back to your routine when you open selected apps. You can build it for your own iPhone with a free Apple Account and Xcode's Personal Team; paid Apple Developer Program membership and Family Controls approval are not required for this edition. [Apple's Personal Team guidance](https://developer.apple.com/help/account/basics/about-your-developer-account) explains this development-install route.

SwiftUI · iOS 17+ · on-device storage · no account inside the app · no backend or dependencies

## What you need

- A Mac with [Xcode](https://developer.apple.com/xcode/) installed. Use an Xcode version that supports your iPhone's iOS version, and finish its first-launch setup and iOS platform download.
- An iPhone running iOS 17 or later, with Apple's **Shortcuts** app installed.
- Your Apple Account, added to Xcode for signing the app.
- A cable to connect your iPhone for the initial installation.
- Internet access for downloading the project and setting up signing. Your routine and redirect decisions work locally afterward.

This is a source-code installation through Xcode. There is no App Store or TestFlight download for this project.

## 1. Download and open the project

On the [GitHub repository page](https://github.com/zaid-brk/MorningReset), click **Code → Download ZIP**, unzip it on your Mac, and open **`MorningReset.xcodeproj`** in Xcode.

If you prefer Terminal, clone it instead:

```sh
git clone https://github.com/zaid-brk/MorningReset.git
cd MorningReset
open MorningReset.xcodeproj
```

In the scheme menu at the top of Xcode, select **MorningResetShortcuts**. The installed app will be named **Morning Reset Shortcuts**.

## 2. Set up signing for your own iPhone

1. Open **Xcode → Settings → Apple Accounts** (called **Accounts** in some versions), and add your Apple Account.
2. In Xcode's left sidebar, click the blue **MorningReset** project icon. Under **TARGETS**, select **MorningResetShortcuts**.
3. Open **Signing & Capabilities**, leave **Automatically manage signing** enabled, and choose your **Personal Team** from the **Team** menu.
4. Give your copy a unique bundle identifier. In the project's `Config` folder, create a plain-text file named **`Local.xcconfig`** containing this line, replacing `yourname` with your own unique name:

   ```xcconfig
   BASE_BUNDLE_IDENTIFIER = com.yourname.morningreset
   ```

5. Return to **Signing & Capabilities**. The Shortcuts target's bundle identifier should now be **`com.yourname.morningreset.Shortcuts`**, using the name you entered. Let Xcode finish creating its signing profile.

`Config/Base.xcconfig` already loads this optional local file. `Config/Local.xcconfig` is ignored by Git, so your identifiers stay local. Selecting your team in Xcode is sufficient; you do not need to look up a Team ID or configure an App Group for the Shortcuts edition. If you already have a working local configuration, keep it.

If Xcode says the bundle identifier is unavailable, change `yourname` to something more distinctive. If it requests Family Controls or App Groups, check that both the selected **scheme** and the **target** are **MorningResetShortcuts**.

## 3. Install and launch on your iPhone

1. Connect your iPhone to the Mac and unlock it. Accept **Trust This Computer** on the iPhone if asked.
2. In the run-destination menu beside the Xcode scheme, choose **your iPhone**, rather than a simulator or a generic iOS device.
3. If Xcode requests Developer Mode, follow its instructions. On the iPhone, open **Settings → Privacy & Security → Developer Mode**, turn it on, restart when prompted, and confirm after restarting. If the setting is missing, first connect the phone and attempt to run from Xcode. See [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
4. In Xcode, press **⌘R**, or click the triangular **Run** button. Xcode builds, installs, and launches **Morning Reset Shortcuts**.
5. If iOS shows **Untrusted Developer**, open **Settings → General → VPN & Device Management**, select the developer entry for your Apple Account, and follow the trust prompt. Then open the app again.

Once installed, you can open the app from your Home Screen without keeping Xcode or your Mac connected. Keep the same signing team and bundle identifier for later builds so they update the same installation.

**Free signing needs renewal:** Personal Team provisioning profiles expire seven days after issuance. If the app stops launching, reconnect the iPhone, open the same project, select **MorningResetShortcuts** and your iPhone, and press **⌘R** again. Rebuild the existing installation rather than deleting it, and check your automation afterward. [Apple documents this expiry and reinstall requirement](https://developer.apple.com/help/account/basics/about-your-developer-account).

## 4. Connect your distracting apps once

The app includes the same instructions during onboarding. Open **Start step-by-step tutorial**, or revisit **Settings → App redirects → Step-by-step setup & test** at any time. Your place in the guide is saved.

On your iPhone:

1. Open **Shortcuts** and tap **Automation** at the bottom.
2. Tap **+** or **New Automation**. If you see **Create Personal Automation**, select it.
3. Find and tap **App** in the trigger list. You can search for App; in the layout used during testing, its row is below CarPlay and above Wallet.
4. Tap **Choose** beside App. Select all the distracting apps you want to interrupt, then tap **Done**. Leave **Morning Reset Shortcuts** and **Shortcuts** unselected to avoid a loop.
5. Select **Is Opened**, leave **Is Closed** unselected, choose **Run Immediately**, and tap **Next**. On older layouts, turn off **Ask Before Running** when saving instead.
6. Choose **New Blank Automation** or **Create New Shortcut** if prompted, then use **Add Action** or **Search Actions**. Search for **Check Morning Redirect** and add the action from **Morning Reset Shortcuts**.
7. Search for **If** and add it below the check. Use the result of **Check Morning Redirect** as its input; select that result using **Select Variable** if necessary. It must test **true / Yes**. Some versions display only **If Check Morning Redirect** for a Boolean input. If it says **Has Any Value**, tap the input variable and change its type to **Boolean** first: a No result still has a value.
8. Add **Open App**, choose **Morning Reset Shortcuts**, and drag that action **between If and Otherwise**. Leave Otherwise empty.
9. Tap **Done** or the blue **checkmark** to save, depending on your iOS version.

The final action order should be:

```text
Check Morning Redirect
If Check Morning Redirect is true / Yes
    Open App → Morning Reset Shortcuts
Otherwise
    [leave empty]
End If
```

**Open App must be inside If, above Otherwise.** If it sits after End If, it will open Morning Reset even when the routine is finished.

You create one automation for several apps together, once per device. To change the selected apps later, edit that automation in Shortcuts. The app cannot install or inspect personal automations. Apple's [app-trigger guide](https://support.apple.com/guide/shortcuts/setting-triggers-apde31e9638b/ios) and [automatic execution settings](https://support.apple.com/guide/shortcuts/apd602971e63/ios) describe the system controls.

## 5. Test the connection and finish setup

1. Return to the last step of the in-app guide and tap **Start 60-second redirect test**.
2. During those 60 seconds, open one of the distracting apps you selected. It should send you back to **Morning Reset Shortcuts**.
3. If you saw the return, tap **I saw the redirect · finish setup**. A successful test check remains confirmable after the timer expires. This confirmation is your report of what happened.
4. Finish onboarding: choose your recurring nightly time, edit your routine, and enable reminders if you want them.
5. **Check the other direction too.** After the test ends, before starting a routine and while no nightly period is active, open a selected app again. It should stay open. In **Settings → Right now**, **Last check** should read **No · allow other apps**.

If a routine period is already active, a Yes result is expected until you complete it or choose **Skip without completing**.

## Using it each morning

At your nightly time, the next attempt to open a selected app begins or checks the redirect period. An app already open on screen is not forcibly closed.

Tap **I'm awake** in Morning Reset to begin your routine. Tap **Start** for each task, then **Complete** when its countdown ends. Tasks are self-confirmed; the app does not verify exercise or hygiene. The final task starts the ten-minute pause automatically.

You can leave the app during the pause. After the saved deadline, the next automation check allows your other apps. A newer nightly period takes precedence over an old routine. Notifications are optional reminders; they do not execute an unlock. You can choose **Skip without completing** to end the current period.

Routine edits apply to your next session, and saved progress survives relaunch. Local history records your routines; this edition does not award protected Screen Time streak credit.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Xcode asks for Screen Time capabilities | Select **MorningResetShortcuts** as both the scheme and signing target. |
| Signing fails | Add your Apple Account, select your Personal Team, and use a unique base bundle identifier in `Config/Local.xcconfig`. |
| iPhone is missing from the destination menu | Unlock and trust it, check the cable, and use an Xcode version that supports its iOS version. |
| Check Morning Redirect is missing in Shortcuts | Launch the installed app once, reopen Shortcuts, and search under its Apps actions. Rebuild if the installation has expired. |
| A selected app never redirects during the test | Start a fresh 60-second test; check the selected apps, Is Opened, Run Immediately, the If input, and the Open App target. |
| An app redirects after the wait or test | In **Settings → Right now**, read **Last check**. If it says **No**, check that If tests the Boolean result, Open App is inside the true branch, and no second automation opens Morning Reset for the same apps. |
| Last check says Yes after a completed session | Check whether a new nightly period or a setup test is active. A newer night starts a fresh period. |
| Setup confirmation is disabled | Start the test and open a selected app while it is running. Confirm only after observing the return. |
| The app stopped launching after several days | Reconnect to Xcode and run the same scheme with the same signing identity and bundle identifier to renew the installation. |

Shortcuts redirects are voluntary interruptions. They may be delayed, may briefly show the distracting app, and can be disabled in Shortcuts. The app cannot guarantee interception if the automation fails to run.

## Other schemes in the repository

| Scheme | Purpose |
| --- | --- |
| **MorningResetShortcuts** | The edition covered by this installation guide: routines plus voluntary app redirects, with free Personal Team signing. |
| **MorningResetDemo** | Routine-only demo with separate local data; no redirects, app shields, or protected streak credit. |
| **MorningReset** | Original Screen Time implementation retained for entitlement-based development. Requires a suitable Apple Developer Program team and capabilities; a free Personal Team cannot provision it. It is not the installation path above. |

The Screen Time implementation and extensions are documented in [feasibility notes](Docs/FEASIBILITY.md), [architecture](Docs/ARCHITECTURE.md), and the original [specification](SPEC.md). It uses a shared App Group and Family Controls capabilities, with foreground release after the ten-minute wait. Screen Time distribution requires [Apple's Family Controls entitlement approval](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). No App Store or TestFlight submission has been made.

## Validation and development

All **37 core tests** passed through the command-line runner and actual XCTest. All three editions compiled in unsigned generic iOS builds with Xcode 27. The Shortcuts edition was also built and launched on a signed iPhone, and the project owner reported working task completion and redirects that stop after the pause. These reports do not establish behavior across all devices; notifications, reboot handling, accessibility, and the full Screen Time implementation still need their physical-device checks. See [the validation record](Docs/VALIDATION.md).

From the project folder, run:

```sh
python3 Scripts/test_core.py
python3 Scripts/check_project.py
```

With full Xcode selected, you can also run Foundation XCTest and build the Shortcuts edition without signing:

```sh
swift test --scratch-path /tmp/morning-reset-build
xcodebuild -project MorningReset.xcodeproj -scheme MorningResetShortcuts \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/morning-reset-shortcuts-build CODE_SIGNING_ALLOWED=NO build
```

The unsigned build checks compilation; use Xcode's signed Run flow above to install on your phone.

`Sources/MorningResetCore` contains Foundation-only session, calendar, redirect, history, and locked-storage logic. `MorningReset/App`, `Views`, and `Services` contain the native UI, App Intent, and reminders. The Shortcuts edition stores authoritative state in its own local JSON file under a cross-process lock, with a SwiftData history mirror. It has no Screen Time entitlement, App Group, or embedded extensions. See [architecture and calendar policies](Docs/ARCHITECTURE.md).

After adding source files, regenerate the committed project and shared schemes:

```sh
python3 Scripts/generate_project.py
```

Every change starts on a new branch from the latest `main`. Push the branch, open a pull request with relevant validation, and wait for the project owner's explicit confirmation before merging. Keep personal signing settings out of commits. See [AGENTS.md](AGENTS.md) for repository guidance.

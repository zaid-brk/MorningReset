# Architecture and state policies

## State machine

`ready` is the absence of an active morning session. The explicit persisted session phases are:

```text
taskReady → taskRunning → awaitingConfirmation
    ↑                           |
    └──── next task ─────────────┘
                         final confirmation
                                 ↓
                         waitingToUnlock → released

Any active phase → bypassed (explicit escape)
Any active phase → interrupted (new protection period)
```

Every task starts through an explicit user action. A deadline enables confirmation; it never confirms the task. The final confirmation creates an absolute deadline 600 seconds later. Drawing a countdown does not execute progression or guarantee background execution. Foreground reconciliation releases only after that deadline.

Protection is a separate `ProtectionPeriod`, with its own UUID, start timestamp, active flag, and prototype flag. A session captures that UUID, the date/time zone of the wake tap, and a copy of the routine. The actual restriction indicator comes from authorization plus the named ManagedSettings store, not merely the session phase.

## New nights and stale work

Before any action or release, compute the most recent due nightly lock. If it is newer than the last handled lock, create a new protection UUID and record any unfinished session as interrupted. The prior session can never unlock the new UUID or earn success. Monitor names include a UUID; callbacks from retired monitor names do not modify protection state. Interval end never clears shielding.

The daily monitor uses a 12-hour calendar interval to remain well above the 15-minute minimum through DST. This window exists to get nightly start callbacks; it is not the protection duration. Protection persists until a successful foreground release or bypass. A one-night override gets an additional one-off monitor. The usual callback consults the override before deciding whether the lock is due.

Enabling protection initially establishes a baseline at the current time; it does not retroactively lock last night. Editing a schedule does not clear a currently active period. Turning off future monitoring also leaves current shielding in place. The explicit escape option ends the current period. A setting moved to a time already passed today is reconciled on save if its due timestamp is newer than the previous handled night.

## Storage and reconciliation

The app and monitor share `state.json` in the entitled App Group. A separate `state.lock` is acquired with `flock` across each read/modify/write and shield update. The file is atomically replaced before restriction side effects, and the lock remains held during those effects. A failed write cannot request an unlock. Corrupt or unsupported state fails visibly rather than silently resetting protection/history. File protection allows access after the first device unlock following reboot.

External ManagedSettings changes and file persistence are not one OS transaction. The ordering deliberately favors retaining a shield on storage errors; foreground/extension reconciliation reapplies the persisted state. There is no absolute guarantee of instantaneous system shield propagation.

SwiftData is a local main-app history mirror. Shared history remains the source of truth, and unique session UUIDs make mirror insertion repeatable. Extensions avoid SwiftData and SwiftUI views, keeping their work small. Optional notification operations are queued in order; newer state cancels superseded pending reminders. Already delivered notifications cannot be retroactively recalled by an extension.

## Streak and time-zone rules

- A success requires a genuinely protected session at start, every timed confirmation, an elapsed ten-minute wait, valid observed Screen Time access, no bypass, and a matching active protection period at reconciliation.
- Demo and manually triggered prototype sessions never count. Replacing/removing selected apps or observing revoked/missing shielding during a session disqualifies protected streak credit. This app cannot prove continuous shielding between observations.
- Store the Gregorian local date and time-zone identifier when “I’m awake” is tapped. Finishing across midnight or traveling never changes that label.
- Deduplicate success by that stored date label, and deduplicate history by session UUID, inside the shared lock.
- Compute current streak using consecutive calendar dates. If today is unfinished, start counting at yesterday. A gap breaks the current streak; best streak remains historical.
- Compute weeks using the current locale's first weekday, the Gregorian calendar, and the device's current time zone. Stored date labels are interpreted as calendar dates in that zone for display statistics; they are never rewritten. If travel makes a recorded date temporarily appear in the future, it does not extend today's current streak or this week's count until that date arrives. The historical best still reflects recorded labels.
- Nightly times follow the current device time zone. Foreground significant-time-change reconciliation refreshes monitoring if the zone changed. A schedule in a spring DST gap moves to the next valid time; the first occurrence is used for an autumn repeated time in core calculations. Actual DeviceActivity handling must be compared on hardware.
- Task/wait durations are elapsed seconds between absolute wall-clock timestamps. Calendar-day streak math never assumes 86,400 seconds per day. Manual clock changes can affect deadlines; the voluntary app does not promise tamper resistance.

## Implementation boundaries

Version one has a daily schedule and an optional today-only override. It stores opaque app tokens locally and shields only directly selected application tokens. Category and website selections are not saved. There are no accounts, networking calls, analytics, subscriptions, exercise recognition, or physical activity claims.

## Standalone Personal Team demo

`MorningResetDemo` is a separate app target and shared scheme compiled with `MORNING_RESET_DEMO`. It excludes `ScreenTimeBridge.swift`, links no FamilyControls/ManagedSettings/DeviceActivity frameworks, has no Screen Time or App Group entitlements, and embeds no extensions. `DemoScreenTimeBridge` reports authorization, selection, and shielding as unavailable; it never simulates protected access.

The demo stores authoritative JSON in its own Application Support directory and mirrors history locally with SwiftData. It shares the routine engine, timers, persistence, reminders, and ten-minute wait. AppModel forces every session to be a demo, disables schedule registration, and rejects prototype shielding. Onboarding skips authorization and protection scheduling; any displayed nightly time is only a saved preview. A persistent banner explains that other apps remain available and protected streaks are not earned. The full app and its extension storage are separate from the demo.

## Independent Shortcuts edition

`MorningResetShortcuts` uses `MORNING_RESET_SHORTCUTS`, a separate `.Shortcuts` bundle ID, and its own local Application Support directory. It links AppIntents but no Screen Time frameworks, requests no App Group or Screen Time entitlement, and embeds no extensions. It never registers DeviceActivity monitoring, applies a shield, or awards protected streak credit. The existing demo remains unchanged in purpose and never offers redirects.

`ShortcutRedirectEngine` holds optional `ShortcutRedirectSettings` in the atomic state file. Enabling establishes a baseline at the current timestamp instead of retroactively starting last night. A due nightly time creates a distinct voluntary period and interrupts an unfinished older routine. An explicit morning start also starts redirects if enabled. Each routine captures the redirect-period UUID while using the routine engine's nonprotected/demo semantics. After the saved 600-second wait, foreground or intent reconciliation finishes the session and ends only the matching period. Pausing stops redirects; resuming during a routine preserves task deadlines. A bypass never first credits an expired wait.

`CheckMorningRedirectIntent` returns a Boolean without opening the app. It belongs only to the app target and uses the same sandbox and cross-process file lock, without an App Group or SwiftData access. The user creates a personal App → Is Opened automation, runs the intent, and uses If → Open App to redirect. Due nights are reconciled before old deadlines. The next intent invocation after a deadline returns false unless a newer period applies, so no timer or notification has to execute at the deadline. The app cannot interrupt an already-foreground app at the scheduled time.

The tutorial appears during onboarding and in Settings, saves its place with SceneStorage, includes loop prevention/action placement, and provides a 60-second test that does not enable nightly redirects on its own. Setup confirmation is the user's report following a test invocation; the recorded intent timestamp only proves the check ran, not that the Open App action executed. Routine checks return the app to Today; test checks preserve the tutorial. No code inspects or creates personal automations. Storage errors propagate from the intent; automation execution/latency and App Intent sandbox access still require physical-device verification.

The original schema version remains readable: the new state/settings and session redirect fields are optional. No migration changes the Screen Time store or demo data. Shortcuts history remains separate and uses nonprotected entries. Nightly times follow the device's current time zone, with the same DST/calendar policies as the Screen Time engine; a due newer timestamp wins after travel. Manual clock changes remain voluntary-system limitations.

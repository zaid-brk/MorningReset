Build a polished native iPhone app with the working name “Morning Reset.” I am a college student building this with Codex, and I want a useful app I can share on GitHub and demonstrate on LinkedIn. It should work for anyone who wants to reduce bedtime and morning scrolling, regardless of their major or profession.

Act as an experienced iOS engineer and product designer. Build a working app, not just a mockup. Keep the architecture understandable for a beginner and explain important decisions briefly.

## 1. Product goal and scope

The app restricts distracting apps at a user-selected nightly time. In the morning, the user opens Morning Reset, taps “I’m awake,” completes a short routine of timed, self-confirmed tasks, and then waits ten minutes before distracting apps become available.

Prioritize very low daily friction. Users configure their routine and schedule once, then follow a simple flow each morning.

Version one does not include QR codes, camera verification, AI, social features, accounts, subscriptions, or a backend. Exercise recognition may be a future update; do not implement it now. The app records timed, self-confirmed completion and must not claim to verify that activities actually happened.

## 2. Stack and project setup

Use:
- Swift and SwiftUI.
- Xcode with an actual buildable project and shared schemes.
- FamilyControls for individual authorization and the system app-selection picker.
- ManagedSettings for shielding selected apps.
- DeviceActivity and appropriate extensions for scheduled restrictions.
- App Groups for the small amount of state shared with extensions.
- SwiftData for local routine and history storage, where appropriate.
- UserNotifications for optional timer-completion notifications.
- SF Symbols, native typography, and native haptics.

Target iOS 17 or later unless a documented technical requirement justifies a higher minimum. Check current Apple documentation before relying on API behavior. Keep dependencies minimal and use Apple frameworks wherever practical.

Keep data on-device for version one. The main routine flow should work offline and require no account. Keep signing identities and personal developer-team details out of the repository.

Inspect the existing workspace before creating or replacing files. Preserve unrelated work. Save this specification as SPEC.md, add concise project guidance in AGENTS.md, and keep README.md accurate.

## 3. Onboarding and settings

Create a short onboarding flow:
1. Briefly explain overnight protection and the morning routine.
2. Request Screen Time authorization and let the user select distracting apps.
3. Choose a recurring nightly lock time.
4. Choose morning tasks and durations.
5. Offer notifications with a clear explanation; declining notifications must not break the routine.

Example defaults, all editable:
- Lock time: 10:30 p.m.
- 10 push-ups: 30 seconds.
- Brush teeth: 2 minutes.
- Use the bathroom: 1 minute.

Use a daily recurring schedule initially, with weekday/weekend overrides if straightforward. Users should be able to adjust tonight without overwriting their usual schedule. Do not ask them to choose a lock time every night.

Only selected apps should be shielded. Do not restrict the entire device.

Settings should show whether Screen Time access is available and explain how to restore it if revoked. If restrictions are inactive, do not imply that protection is working.

## 4. Routine customization

Provide task presets:
- Push-ups.
- Jumping jacks.
- Stretching.
- Brush teeth.
- Use the bathroom.
- Drink water.
- Make the bed.

Also provide “Write your own.”

Each task has:
- An editable title, including the desired repetitions where relevant.
- An editable duration.
- A minimum duration of 15 seconds.

Users can add, delete, and reorder tasks. Require at least one task before starting a protected morning routine. Recommend a short routine without imposing an arbitrary maximum.

Persist the routine. Capture a snapshot when a morning session starts so editing the template does not change an active task or its countdown. Explain that edits apply to the next session.

## 5. Exact daily flow

At the nightly lock time, selected distracting apps become shielded. Protection should continue across midnight until the morning release flow succeeds, unless the user explicitly overrides it.

Do not detect wake-up automatically. The morning starts when the user taps “I’m awake.”

Then:
1. Show the first task by itself, with its title, duration, and progress such as “1 of 3.”
2. The user taps Start.
3. Run that task’s countdown.
4. Keep Complete disabled until the countdown expires.
5. Once it expires, enable Complete. The user can take longer before confirming.
6. After confirmation, advance to the next task.
7. Start each task only when the user taps Start. Never run task timers concurrently or automatically complete tasks.
8. After the final confirmation, start the ten-minute waiting period automatically.
9. Keep selected apps shielded during the waiting period.
10. After the waiting period, release the morning restriction using a verified, supported implementation.

During the waiting period, show:
“Routine complete. Your apps unlock in 10 minutes.”
“You can put your phone down.”

Display the remaining time when the user returns. Send an optional notification at expiry with wording that accurately reflects whether the apps were actually released.

The user should not have to leave the app open or watch the timer. Preserve progress when the app is backgrounded, terminated, or the phone restarts. Use persisted start/end timestamps to calculate remaining time, rather than relying on a constantly running in-memory countdown.

Provide an explicit “Unlock without completing” escape option with confirmation. Record the session as bypassed; do not award a successful-routine streak. Avoid manipulative messaging. Individual Screen Time authorization is voluntary; do not promise an impossible-to-bypass lock.

If the next nightly lock occurs during an unfinished session, the new protection period must take precedence. Old timers or callbacks must not accidentally unlock the new period. Define and document what happens to the unfinished session.

## 6. Verify the hardest iOS behavior first

Before building the full UI, prototype these on a real iPhone where available:
- Individual Screen Time authorization.
- Selecting, shielding, and releasing an app.
- Scheduled nightly shielding while the main app is not running.
- Persisting task progress across backgrounding and relaunch.
- Releasing restrictions after the ten-minute waiting period.

Apple’s DeviceActivity monitoring intervals have a documented fifteen-minute minimum. Investigate how that affects the ten-minute release requirement. Do not assume a ten-minute DeviceActivity interval is supported. Do not assume an ordinary background timer, background refresh request, or local notification can execute an unlock at an exact time while the app is suspended.

Prefer a supported automatic release mechanism, and document evidence and real-device results. If exact automatic ten-minute release cannot be achieved reliably, keep the ten-minute product requirement and clearly implement a labeled fallback: notification at expiry, with release when the user next opens the app after the deadline. Document the limitation rather than silently changing the wait to fifteen minutes or claiming automatic release works.

Keep prototype/demo behavior visibly separate from real Screen Time behavior. Do not substitute a simulated block screen for actual restrictions and call the app complete.

## 7. Routine streaks

A successful morning requires:
- Confirmation of every task after its timer expires.
- Completion of the ten-minute waiting period.
- No bypass.
- An active protected session; demo sessions do not count as protected successes.

Show:
- Current streak.
- Best streak.
- Successful mornings this week.

Count at most one success per local calendar day. Use the local date when “I’m awake” was tapped as that session’s date, even if it finishes after midnight. Use calendar-date arithmetic rather than assuming every day is exactly 24 hours.

Consecutive successful dates extend the streak. A missed day ends it. An unfinished current day should not prematurely erase yesterday’s streak. A bypass does not count as success.

Credit an elapsed waiting period once when the app or an appropriate extension reconciles the session. Persist history and avoid duplicate credit from repeated callbacks or relaunches. Document consistent handling of travel/time-zone changes and test daylight-saving boundaries.

Use friendly wording. Call this a routine streak, not verified exercise or hygiene compliance.

## 8. Design direction

Make the app feel calm, polished, and native to iPhone:
- Warm off-white background in light mode.
- Charcoal background in dark mode.
- Muted orange as the primary accent.
- System typography, clear hierarchy, generous spacing.
- Rounded cards and large, comfortable touch targets.
- A clean circular countdown with readable remaining time.
- Subtle transitions and gentle completion haptics.
- Strong contrast, Dynamic Type, VoiceOver labels, and Reduce Motion support.

Keep navigation to:
- Today: protection status, “I’m awake,” active routine or waiting period, and compact streak information.
- Routine: task presets, custom tasks, durations, and ordering.
- Settings: selected apps, schedule, permissions, and escape option.

Present the active routine as a focused screen with one task and one clear primary action. Make the blocked-app shield visually consistent within Apple’s supported customization limits. Avoid busy dashboards, excessive gradients, childish gamification, and unnecessary text.

Choose sensible visual details without repeatedly asking me to approve minor decisions.

## 9. Architecture and validation

Use small SwiftUI views and clearly separated routine, persistence, and restriction logic. Model the session explicitly: ready, task ready, task running, awaiting confirmation, waiting to unlock, released, or bypassed. Keep actual restriction status separate from routine status.

Use an injectable clock for meaningful tests. Ensure the main app and extensions reconcile shared state safely and never award duplicate successes.

Test:
- The 15-second task minimum and disabled early completion.
- Sequential task progression and delayed user confirmation.
- Ten-minute deadline calculation.
- Backgrounding/relaunch without resetting progress.
- Bypass behavior and streak eligibility.
- Midnight, missed days, duplicate completions, and daylight-saving changes.
- Protection-period precedence and stale unlock callbacks.
- Schedule updates and permission revocation.

Build and run tests with Xcode tools when available. Test actual shielding and extension behavior on physical hardware. If this environment lacks macOS, Xcode, signing, or an iPhone, clearly state what you cannot validate and provide exact steps for me to run locally. Do not claim compilation or device behavior was verified if it was not.

## 10. Deliverables and execution

Deliver:
- The complete Xcode project with required extension targets.
- SPEC.md and concise AGENTS.md.
- README.md with setup, architecture, signing, App Groups, required entitlements, running tests, physical-device checks, and TestFlight preparation.
- A clear list of verified behavior and remaining platform limitations.
- A GitHub-friendly repository without secrets or personal signing credentials.

Explain that Family Controls distribution requires Apple approval for the relevant app/extension capabilities. Prepare the project for that process, but do not publish, submit to the App Store, or create public repositories without my explicit instruction.

Start with a brief implementation plan and the Screen Time feasibility prototype. Then continue implementing the app in manageable stages. Make routine technical decisions independently and only ask me about genuine product blockers or choices that materially change the requested experience.

At completion, summarize what works, what was tested, what needs a real-device check, and the exact next steps for running it on my iPhone.

## Approved amendment — Shortcuts redirects (2026-10-03)

The user approved an alternative to entitled app blocking: a voluntary Shortcuts automation that sends users back to Morning Reset when they open selected distracting apps during a nightly routine period. Include a clear step-by-step in-app tutorial during onboarding and in Settings. Users configure one app-opening automation per device and can choose several apps together. The app supplies a Boolean App Intent; the automation runs it, then uses If → Open App to redirect only when requested.

Deliver this as the independent `MorningResetShortcuts` target, with Personal Team signing support, no Screen Time frameworks or entitlements, no App Groups, no embedded extensions, and separate local storage. Preserve the existing Screen Time and demo editions; the demo remains demo-only and never redirects other apps.

Retain the timed, self-confirmed routine and ten-minute pause. Evaluate the recurring nightly schedule and saved deadlines on app entry and each intent invocation. The next check after an elapsed wait permits the distracting app without requiring a separate foreground return. A newer nightly period takes precedence over any old routine. Notifications remain reminders and never execute an unlock. Provide an explicit bypass and a time-limited setup test.

Describe redirects accurately: they are voluntary, may be delayed or fail, may briefly show the distracting app, cannot close an already-foreground app at the nightly time, and can be disabled in Shortcuts. Do not claim the app can install or verify the automation. Setup status is the user's confirmation following a test. Shortcuts routines use nonprotected session/history semantics and never earn protected streak credit. Personal Team installation expiry remains a development-signing limitation; no distribution is authorized by this amendment.

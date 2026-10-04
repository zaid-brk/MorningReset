# Morning Reset

- Read SPEC.md before changing product behavior. Keep the app native, offline, and beginner-readable.
- Use SwiftUI and Apple frameworks; minimum iOS 17. Do not add accounts, AI, a backend, or dependencies.
- `Sources/MorningResetCore` is Foundation-only and shared by the app and monitor. Run `python3 Scripts/test_core.py` after core changes; `swift test --scratch-path /tmp/morning-reset-build` is also available with full Xcode/XCTest installed.
- Shared state uses an App Group file protected by a cross-process lock. Change restrictions inside the same transaction as protection state. Never clear a newer protection period from an old session.
- Ten-minute release uses the documented foreground fallback. Notifications remind; they do not execute an unlock. Do not claim automatic background release or verified physical activity.
- Keep prototype actions clearly labeled, and exclude them from protected streaks.
- Keep `MorningResetDemo` free of Screen Time frameworks, entitlements, App Groups, and embedded extensions. Force its sessions to be demos, use separate local storage, and never award protected streak credit.
- Keep `MorningResetShortcuts` separate from the demo and Screen Time app. Use local locked storage and App Intents; never add Screen Time capabilities or protected streak credit. Redirects are voluntary, setup is user-confirmed, and the app cannot install or verify personal automations. Keep the onboarding/Settings tutorial accurate.
- Run `python3 Scripts/generate_project.py` after adding source files. Commit the generated Xcode project and shared schemes. Keep signing teams and credentials out of source control.
- Run iOS builds/tests with Xcode when available. Record limitations honestly in Docs/VALIDATION.md. Physical Screen Time behavior requires an entitled, signed iPhone build.
- For every change, create a new branch from the latest `main` before editing. Use `feat/`, `fix/`, or `chore/` names as appropriate; documentation and configuration changes also require a branch.
- Push only the working branch and open a pull request with the problem, resulting behavior, and relevant validation. Never push changes directly to `main` or bypass its protection.
- Wait for the user's explicit confirmation before merging a pull request. Do not enable auto-merge or treat approval of a feature request as approval to merge. If feedback requires changes, update the same pull request and report the new result before merging.
- Do not publish, submit, or create public repositories without explicit user instructions.

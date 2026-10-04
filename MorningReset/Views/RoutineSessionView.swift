import SwiftUI

struct RoutineSessionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: MorningSession
    @State private var confirmBypass = false
    private var waiting: Bool { session.phase == .waitingToUnlock }

    var body: some View {
        VStack(spacing: 24) {
            if BuildMode.usesShortcuts {
                Label(model.redirectSettings.enabled ? "Shortcuts routine · redirects need your connected automation" : "Routine only · app redirects are paused", systemImage: "arrow.uturn.backward")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if (session.isDemo && !BuildMode.isDemo) || session.isPrototype {
                Label(session.isDemo ? "Demo · no app restrictions or streak credit" : "Prototype · real shields, no streak credit", systemImage: "info.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !session.isDemo && !model.shieldApplied {
                Label("Protection is inactive. This session cannot earn a protected streak.", systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if waiting {
                Eyebrow(text: "Room to breathe")
                Text(BuildMode.usesShortcuts && model.redirectSettings.enabled ? "Routine complete. Redirects end after ten minutes." : session.isDemo ? "Routine complete. Take ten minutes for yourself." : "Routine complete. Your apps unlock in 10 minutes.")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Text("You can put your phone down.").foregroundStyle(.secondary)
            } else {
                Eyebrow(text: "\(session.taskIndex + 1) of \(session.tasks.count)")
                if let task = session.currentTask {
                    Image(systemName: ResetTheme.symbol(for: task.title)).font(.system(size: 44))
                        .foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                    Text(task.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let total = waiting ? 600 : session.currentTask?.duration ?? 15
                let deadline = waiting ? session.unlockDeadline : session.taskDeadline
                let remaining = deadline.map { max(0, $0.timeIntervalSince(timeline.date)) } ?? total
                CountdownRing(remaining: remaining, total: total, ready: session.phase == .taskReady)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.phase)
            }
            if waiting {
                ResetCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(BuildMode.usesShortcuts ? "Your progress is saved" : session.isDemo ? "Return after your ten-minute pause" : "Open Morning Reset after the wait", systemImage: "hand.tap")
                            .font(.headline)
                        Text(BuildMode.usesShortcuts ? "You can close this app. After the saved deadline, the next automation check stops redirecting for this period. A newer nightly period takes precedence. Reminders do not execute an unlock." : session.isDemo ? "Your deadline is saved even if you close the demo. Come back after it ends to finish the session. Other apps stay available throughout." : "The ten-minute deadline is saved. Your apps release when you next open this app after it ends; the optional reminder does not unlock them.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                if session.phase == .taskReady {
                    Text("\(ResetTheme.duration(session.currentTask?.duration ?? 15)) · start when you’re ready")
                        .font(.subheadline).foregroundStyle(.secondary)
                    PrimaryButton(title: "Start", symbol: "play.fill") { model.startTask() }
                } else {
                    Text(session.phase == .awaitingConfirmation ? "Take your time. Confirm when you’ve finished." : "Complete becomes available when the timer ends.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    PrimaryButton(title: "Complete", symbol: "checkmark", disabled: session.phase != .awaitingConfirmation) { model.completeTask() }
                }
            }
            Button(BuildMode.usesShortcuts ? "Skip without completing" : session.isDemo ? "End demo without completing" : "Unlock without completing") { confirmBypass = true }
                .font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 44)
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
        .confirmationDialog(BuildMode.usesShortcuts ? "Skip this redirect period?" : session.isDemo ? "End this demo session?" : "Unlock without completing?", isPresented: $confirmBypass, titleVisibility: .visible) {
            Button(BuildMode.usesShortcuts ? "Skip without completing" : session.isDemo ? "End demo" : "Unlock without completing", role: .destructive) { model.bypass() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("This session will be recorded as bypassed and won’t add to your routine streak.") }
    }
}

struct CountdownRing: View {
    let remaining: TimeInterval
    let total: TimeInterval
    let ready: Bool
    var body: some View {
        ZStack {
            Circle().stroke(ResetTheme.accent.opacity(0.12), lineWidth: 10)
            Circle().trim(from: 0, to: ready ? 0 : min(1, max(0, 1 - remaining / max(1, total))))
                .stroke(ResetTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 8) {
                Text(ResetTheme.countdown(remaining)).font(.system(.largeTitle, design: .rounded).weight(.medium))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                Text(ready ? "READY" : remaining <= 0 ? "TIMER COMPLETE" : "REMAINING")
                    .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            }.padding(28)
        }.frame(maxWidth: 280).aspectRatio(1, contentMode: .fit).padding(12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ready ? "Task duration" : "Time remaining")
            .accessibilityValue(ResetTheme.duration(remaining))
    }
}

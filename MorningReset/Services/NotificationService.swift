import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    override init() { super.init(); center.delegate = self }

    func request() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func sync(state: ResetState) async throws {
        // Serialize calls from AppModel. Cancel pending reminders when a new protection period supersedes a session.
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix("morning-reset.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard state.notificationsEnabled, let session = state.session, !session.isFinished else { return }
        let deadline: Date
        let content = UNMutableNotificationContent()
        let identifier: String
        if session.phase == .taskRunning, let taskDeadline = session.taskDeadline, let task = session.currentTask {
            deadline = taskDeadline
            identifier = "morning-reset.task.\(session.id).\(session.taskIndex)"
            content.title = "Timer complete"
            content.body = "\(task.title): confirm when you’re ready in Morning Reset."
        } else if session.phase == .waitingToUnlock, let waitDeadline = session.unlockDeadline {
            deadline = waitDeadline
            identifier = "morning-reset.wait.\(session.id)"
            content.title = "Your ten-minute wait has ended"
            content.body = session.isDemo ? "Open Morning Reset to finish your demo."
                : "Open Morning Reset to release this session’s restriction. A newer night may still be protected."
        } else { return }
        guard deadline > Date() else { return }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

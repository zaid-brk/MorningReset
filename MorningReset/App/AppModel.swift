import SwiftUI
#if !MORNING_RESET_DEMO
import FamilyControls
#endif
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = ResetState()
    @Published private(set) var shieldApplied = false
    @Published private(set) var monitoringActive = false
    @Published var errorMessage: String?
    @Published private(set) var storageUnavailable = false
    private var store: LockedStateStore?
    private var archive: HistoryArchive?
    private let notifications = NotificationService()
    private var notificationQueue: Task<Void, Never>?
    private var lastDisplayDate = CalendarRules.dateKey(Date(), calendar: CalendarRules.localCalendar())

    var engine: RoutineEngine { RoutineEngine() }
    var activeSession: MorningSession? { state.session?.isFinished == false ? state.session : nil }
    var streak: StreakSummary {
        .calculate(history: state.history, now: Date(), calendar: CalendarRules.localCalendar())
    }

    init() {
        do { store = try SharedEnvironment.makeStore() }
        catch { storageUnavailable = true; errorMessage = error.localizedDescription }
        do { archive = try HistoryArchive() }
        catch { errorMessage = "History archive unavailable: \(error.localizedDescription). Shared routine history is still retained." }
        refresh()
    }

    /// All state changes and shield writes occur under one process-shared lock.
    @discardableResult
    private func change(_ body: (inout ResetState) throws -> Void) -> Bool {
        guard let store else { errorMessage = SetupError.appGroup.localizedDescription; return false }
        do {
            state = try store.transaction(afterCommit: ScreenTimeBridge.finishMainAppCommit) { state in
                state.accessAvailable = ScreenTimeBridge.authorized
                state.selectionCount = ScreenTimeBridge.selectedAppCount(in: state)
                if BuildMode.isDemo { state.scheduleEnabled = false; state.protection = nil }
                if state.session?.isFinished == false, state.session?.isDemo == false,
                   !ScreenTimeBridge.shieldApplied(for: state) { state.session?.eligible = false }
                try body(&state)
                return state
            }
            shieldApplied = ScreenTimeBridge.shieldApplied(for: state)
            monitoringActive = ScreenTimeBridge.isRegistered(state)
            storageUnavailable = false
            lastDisplayDate = CalendarRules.dateKey(Date(), calendar: CalendarRules.localCalendar())
            do { try archive?.sync(state.history) }
            catch { errorMessage = "The local history mirror could not update. Shared history remains saved: \(error.localizedDescription)" }
            queueNotifications()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func refresh() {
        change { state in
            if state.scheduleEnabled, state.accessAvailable,
               !ScreenTimeBridge.isRegistered(state) || state.scheduleTimeZoneID != TimeZone.current.identifier {
                do { try ScreenTimeBridge.register(&state, now: Date(), calendar: CalendarRules.localCalendar()) }
                catch {
                    state.log("Schedule recovery failed: \(error.localizedDescription)", at: Date())
                    errorMessage = "Nightly schedule could not be restored: \(error.localizedDescription)"
                }
            }
            engine.reconcile(&state, mayRelease: true)
        }
    }

    func tick() {
        let calendar = CalendarRules.localCalendar()
        let now = Date()
        let nightIsDue = state.scheduleEnabled && state.lastHandledNight.map {
            CalendarRules.latestNight(in: state, at: now, calendar: calendar) > $0
        } == true
        if ScreenTimeBridge.authorized != state.accessAvailable
            || ScreenTimeBridge.shieldApplied(for: state) != shieldApplied
            || CalendarRules.dateKey(now, calendar: calendar) != lastDisplayDate || nightIsDue {
            refresh()
            return
        }
        guard let session = activeSession else { return }
        let deadline = session.phase == .taskRunning ? session.taskDeadline
            : session.phase == .waitingToUnlock ? session.unlockDeadline : nil
        if let deadline, now >= deadline { refresh() }
        // No disk writes per second: TimelineView draws from persisted deadlines.
    }

    func authorize() async {
        #if MORNING_RESET_DEMO
        errorMessage = SetupError.demoUnavailable.localizedDescription
        #else
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual); refresh() }
        catch { errorMessage = "Screen Time access was not enabled. \(error.localizedDescription)"; refresh() }
        #endif
    }

    #if !MORNING_RESET_DEMO
    func saveSelection(_ selected: FamilyActivitySelection) {
        change { state in
            var appsOnly = FamilyActivitySelection()
            appsOnly.applicationTokens = selected.applicationTokens
            let changed = ScreenTimeBridge.selection(in: state).applicationTokens != appsOnly.applicationTokens
            state.selectionData = try JSONEncoder().encode(appsOnly)
            state.selectionCount = appsOnly.applicationTokens.count
            // Removing or replacing a protected app set mid-session cannot earn a protected streak.
            if changed, state.session?.isFinished == false { state.session?.eligible = false }
            engine.reconcile(&state, mayRelease: true)
        }
    }
    #endif

    func saveRoutine(_ tasks: [RoutineTask]) {
        change { state in
            state.routine = tasks.map { RoutineTask(id: $0.id, title: $0.title, duration: $0.duration) }
        }
    }

    func setSchedule(time: LockTime, override: TonightOverride?, enabled: Bool) {
        change { state in
            state.lockTime = time
            state.tonightOverride = override
            if enabled && !BuildMode.isDemo { try ScreenTimeBridge.register(&state, now: Date(), calendar: CalendarRules.localCalendar()) }
            else { ScreenTimeBridge.disableSchedule(&state) }
            engine.reconcile(&state, mayRelease: true)
        }
    }

    func finishOnboarding() { change { $0.onboardingComplete = true } }
    func startMorning(demo: Bool = false) {
        if change({ state in
            engine.reconcile(&state, mayRelease: true)
            let applied = ScreenTimeBridge.shieldApplied(for: state)
            try engine.startMorning(&state, demo: demo || BuildMode.isDemo, shieldApplied: applied)
        }) { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }
    func startTask() { change { try engine.startTask(&$0) } }
    func completeTask() {
        if change({ try engine.confirmTask(&$0) }) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
    func bypass() { change { engine.bypass(&$0) } }
    func prototypeLock() {
        guard !BuildMode.isDemo else { errorMessage = SetupError.demoUnavailable.localizedDescription; return }
        change { state in
            guard state.accessAvailable, state.selectionCount > 0 else { throw RoutineError.protectionUnavailable }
            engine.beginProtection(&state, at: Date(), prototype: true)
        }
    }

    func enableNotifications() async {
        do {
            let enabled = try await notifications.request()
            change { $0.notificationsEnabled = enabled }
            if !enabled { errorMessage = "Notifications are off. Your routine still works; you can enable reminders in iPhone Settings." }
        } catch { errorMessage = error.localizedDescription }
    }
    func disableNotifications() { change { $0.notificationsEnabled = false } }

    private func queueNotifications() {
        let previous = notificationQueue
        let snapshot = state
        notificationQueue = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do { try await notifications.sync(state: snapshot) }
            catch { errorMessage = "Could not schedule the optional reminder: \(error.localizedDescription)" }
        }
    }
}

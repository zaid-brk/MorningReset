import Foundation

public struct RoutineEngine {
    public let clock: any ResetClock
    public var calendar: Calendar
    public init(clock: any ResetClock = SystemClock(), calendar: Calendar = CalendarRules.localCalendar()) {
        self.clock = clock
        self.calendar = calendar
    }

    /// Called before every action and by nightly callbacks. A new night always wins over an old deadline.
    public func reconcile(_ state: inout ResetState, mayRelease: Bool) {
        let now = clock.now
        if state.scheduleEnabled {
            let due = CalendarRules.latestNight(in: state, at: now, calendar: calendar)
            if state.lastHandledNight == nil || due > state.lastHandledNight! {
                beginProtection(&state, at: due, prototype: false)
                state.lastHandledNight = due
            }
        }
        guard var session = state.session, !session.isFinished else { return }
        if !session.isDemo && (!state.accessAvailable || state.selectionCount == 0) {
            session.eligible = false
        }
        if !session.isDemo && session.protectionID != state.protection?.id {
            session.phase = .interrupted
            session.eligible = false
            state.session = session
            record(&state, session: session, outcome: .interrupted, success: false)
            return
        }
        if session.phase == .taskRunning, let deadline = session.taskDeadline, now >= deadline {
            session.phase = .awaitingConfirmation
        }
        if mayRelease, session.phase == .waitingToUnlock, let deadline = session.unlockDeadline, now >= deadline {
            session.phase = .released
            let protected = session.eligible && !session.isDemo && !session.isPrototype
                && state.accessAvailable && state.selectionCount > 0 && state.protection?.active == true
                && state.protection?.id == session.protectionID
            let duplicateDay = state.history.contains { $0.protectedSuccess && $0.localDate == session.localDate }
            let success = protected && !duplicateDay
            session.successRecorded = success
            if !session.isDemo && state.protection?.id == session.protectionID {
                state.protection?.active = false
            }
            state.session = session
            record(&state, session: session, outcome: .released, success: success)
            state.log("Wait reconciled; foreground release requested", at: now)
            return
        }
        state.session = session
    }

    public func beginProtection(_ state: inout ResetState, at date: Date, prototype: Bool) {
        interruptSession(&state)
        state.protection = ProtectionPeriod(startedAt: date, isPrototype: prototype)
        state.log(prototype ? "Prototype protection started (no streak credit)" : "New nightly protection period", at: clock.now)
    }

    /// Shared by real protection and voluntary redirects when a newer night takes precedence.
    public func interruptSession(_ state: inout ResetState) {
        if var session = state.session, !session.isFinished {
            session.phase = .interrupted
            session.eligible = false
            record(&state, session: session, outcome: .interrupted, success: false)
            state.session = session
        }
    }

    /// Retired registrations cannot change access, progress, or the current protection period.
    @discardableResult
    public func handleMonitorEvent(_ state: inout ResetState, name: String,
                                   accessAvailable: Bool, selectedApps: Int) -> Bool {
        guard state.scheduleEnabled,
              name == state.monitorName || name == state.overrideMonitorName else { return false }
        state.accessAvailable = accessAvailable
        state.selectionCount = selectedApps
        reconcile(&state, mayRelease: false)
        return true
    }

    public func startMorning(_ state: inout ResetState, demo: Bool = false, shieldApplied: Bool = false) throws {
        reconcile(&state, mayRelease: true)
        guard state.session?.isFinished != false else { throw RoutineError.activeSession }
        guard !state.routine.isEmpty, state.routine.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RoutineError.emptyRoutine
        }
        guard demo || (state.protection?.active == true && state.accessAvailable && state.selectionCount > 0 && shieldApplied) else {
            throw RoutineError.protectionUnavailable
        }
        let snapshot = state.routine.map { RoutineTask(id: $0.id, title: $0.title, duration: $0.duration) }
        state.session = MorningSession(
            localDate: CalendarRules.dateKey(clock.now, calendar: calendar),
            timeZoneID: calendar.timeZone.identifier, startedAt: clock.now, tasks: snapshot,
            protectionID: demo ? nil : state.protection?.id, eligible: !demo,
            isDemo: demo, isPrototype: !demo && state.protection?.isPrototype == true
        )
    }

    public func startTask(_ state: inout ResetState) throws {
        reconcile(&state, mayRelease: true)
        guard var session = state.session, session.phase == .taskReady, let task = session.currentTask else {
            throw RoutineError.wrongPhase
        }
        session.taskDeadline = clock.now.addingTimeInterval(max(15, task.duration))
        session.phase = .taskRunning
        state.session = session
    }

    public func confirmTask(_ state: inout ResetState) throws {
        reconcile(&state, mayRelease: true)
        guard var session = state.session else { throw RoutineError.wrongPhase }
        if session.phase == .taskRunning { throw RoutineError.timerNotFinished }
        guard session.phase == .awaitingConfirmation else { throw RoutineError.wrongPhase }
        session.taskDeadline = nil
        if session.taskIndex + 1 < session.tasks.count {
            session.taskIndex += 1
            session.phase = .taskReady
        } else {
            session.phase = .waitingToUnlock
            session.unlockDeadline = clock.now.addingTimeInterval(600)
        }
        state.session = session
    }

    public func bypass(_ state: inout ResetState) {
        // Do not first credit an expired wait: an explicit bypass always means no success.
        reconcile(&state, mayRelease: false)
        if state.session == nil || state.session?.isFinished == true {
            state.session = MorningSession(localDate: CalendarRules.dateKey(clock.now, calendar: calendar),
                timeZoneID: calendar.timeZone.identifier, startedAt: clock.now, tasks: [],
                protectionID: state.protection?.id, eligible: false, isDemo: false,
                isPrototype: state.protection?.isPrototype == true)
        }
        guard var session = state.session else { return }
        session.phase = .bypassed
        session.eligible = false
        session.unlockDeadline = nil
        session.taskDeadline = nil
        // Escape applies to the current period, even if a new night just interrupted a prior session.
        state.protection?.active = false
        state.session = session
        record(&state, session: session, outcome: .bypassed, success: false)
        state.log("User chose unlock without completing", at: clock.now)
    }

    private func record(_ state: inout ResetState, session: MorningSession, outcome: SessionPhase, success: Bool) {
        guard !state.history.contains(where: { $0.id == session.id }) else { return }
        state.history.append(HistoryEntry(id: session.id, localDate: session.localDate, timeZoneID: session.timeZoneID,
            startedAt: session.startedAt, finishedAt: clock.now, outcome: outcome, protectedSuccess: success,
            isDemo: session.isDemo, isPrototype: session.isPrototype))
    }
}

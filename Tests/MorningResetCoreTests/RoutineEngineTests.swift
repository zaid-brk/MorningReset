import Foundation
#if !CORE_TEST_RUNNER
import XCTest
#if XCODE_TEST_TARGET
@testable import MorningReset
#else
@testable import MorningResetCore
#endif
#endif

final class RoutineEngineTests: XCTestCase {
    var calendar: Calendar { CalendarRules.localCalendar(timeZone: TimeZone(identifier: "America/Chicago")!) }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func engine(_ text: String) -> RoutineEngine { RoutineEngine(clock: FixedClock(now: date(text)), calendar: calendar) }
    func protected(_ time: String = "2026-10-03T12:00:00Z", prototype: Bool = false) -> ResetState {
        var s = ResetState()
        s.accessAvailable = true
        s.selectionCount = 1
        s.routine = [RoutineTask(title: "Drink water", duration: 15), RoutineTask(title: "Brush teeth", duration: 120)]
        engine(time).beginProtection(&s, at: date(time), prototype: prototype)
        return s
    }
    func waiting(_ time: String = "2026-10-03T12:00:00Z", demo: Bool = false, prototype: Bool = false) throws -> ResetState {
        var s = protected(time, prototype: prototype)
        s.routine = [RoutineTask(title: "Water", duration: 15)]
        let e = engine(time)
        try e.startMorning(&s, demo: demo, shieldApplied: true)
        try e.startTask(&s)
        let later = RoutineEngine(clock: FixedClock(now: date(time).addingTimeInterval(15)), calendar: calendar)
        try later.confirmTask(&s)
        return s
    }

    func testMinimumAndEarlyCompletion() throws {
        var s = protected()
        s.routine = [RoutineTask(title: "Water", duration: 1)]
        XCTAssertEqual(s.routine[0].duration, 15)
        let e = engine("2026-10-03T12:00:00Z")
        try e.startMorning(&s, shieldApplied: true)
        try e.startTask(&s)
        XCTAssertThrowsError(try e.confirmTask(&s)) { XCTAssertEqual($0 as? RoutineError, .timerNotFinished) }
        XCTAssertEqual(s.session?.phase, .taskRunning)
    }

    func testEveryTaskCanBeConfirmedAtItsDeadlineWithoutARefresh() throws {
        var state = protected()
        state.routine = [
            RoutineTask(title: "Water", duration: 15),
            RoutineTask(title: "10 push-ups", duration: 30),
            RoutineTask(title: "Stretch", duration: 60),
            RoutineTask(title: "Brush teeth", duration: 120)
        ]
        var now = date("2026-10-03T12:00:00Z").addingTimeInterval(0.25)
        try RoutineEngine(clock: FixedClock(now: now), calendar: calendar).startMorning(&state, shieldApplied: true)
        for index in state.routine.indices {
            XCTAssertFalse(state.session!.canConfirmTask(at: now))
            try RoutineEngine(clock: FixedClock(now: now), calendar: calendar).startTask(&state)
            let deadline = state.session!.taskDeadline!
            let before = deadline.addingTimeInterval(-0.01)
            XCTAssertFalse(state.session!.canConfirmTask(at: before))
            XCTAssertThrowsError(try RoutineEngine(clock: FixedClock(now: before), calendar: calendar).confirmTask(&state))
            // No tick/reconcile ran at expiry: the persisted phase still says running.
            XCTAssertEqual(state.session?.phase, .taskRunning)
            var restored = try JSONDecoder().decode(ResetState.self, from: JSONEncoder().encode(state))
            XCTAssertTrue(restored.session!.canConfirmTask(at: deadline))
            XCTAssertTrue(restored.session!.canConfirmTask(at: deadline.addingTimeInterval(90)))
            try RoutineEngine(clock: FixedClock(now: deadline), calendar: calendar).confirmTask(&restored)
            state = restored
            XCTAssertEqual(state.session?.taskIndex, min(index + 1, state.routine.count - 1))
            XCTAssertEqual(state.session?.phase, index == state.routine.count - 1 ? .waitingToUnlock : .taskReady)
            XCTAssertFalse(state.session!.canConfirmTask(at: deadline))
            now = deadline.addingTimeInterval(2)
        }
    }

    func testSequentialTasksNeedExplicitStartAndConfirmation() throws {
        var s = protected()
        let e = engine("2026-10-03T12:00:00Z")
        try e.startMorning(&s, shieldApplied: true)
        XCTAssertEqual(s.session?.phase, .taskReady)
        try e.startTask(&s)
        XCTAssertThrowsError(try e.startTask(&s))
        let later = engine("2026-10-03T12:05:00Z")
        later.reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.session?.phase, .awaitingConfirmation)
        XCTAssertEqual(s.session?.taskIndex, 0)
        try later.confirmTask(&s)
        XCTAssertEqual(s.session?.taskIndex, 1)
        XCTAssertEqual(s.session?.phase, .taskReady)
        XCTAssertNil(s.session?.taskDeadline)
        try later.startTask(&s)
        XCTAssertEqual(s.session?.taskDeadline, date("2026-10-03T12:07:00Z"))
    }

    func testSnapshotUnaffectedByTemplateEdits() throws {
        var s = protected()
        try engine("2026-10-03T12:00:00Z").startMorning(&s, shieldApplied: true)
        s.routine.removeAll()
        XCTAssertEqual(s.session?.tasks.count, 2)
        XCTAssertEqual(s.session?.tasks.first?.duration, 15)
    }

    func testTenMinutesStartsAtFinalConfirmation() throws {
        var s = protected()
        s.routine = [RoutineTask(title: "Water", duration: 15)]
        let e = engine("2026-10-03T12:00:00Z")
        try e.startMorning(&s, shieldApplied: true)
        try e.startTask(&s)
        try engine("2026-10-03T12:08:00Z").confirmTask(&s)
        XCTAssertEqual(s.session?.unlockDeadline, date("2026-10-03T12:18:00Z"))
        engine("2026-10-03T12:17:59Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.protection?.active, true)
        engine("2026-10-03T12:18:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.protection?.active, false)
        XCTAssertEqual(s.history.filter(\.protectedSuccess).count, 1)
    }

    func testForegroundFallbackAndDuplicateReconciliation() throws {
        var s = try waiting()
        let e = engine("2026-10-03T12:11:00Z")
        e.reconcile(&s, mayRelease: false)
        XCTAssertEqual(s.session?.phase, .waitingToUnlock)
        XCTAssertEqual(s.protection?.active, true)
        e.reconcile(&s, mayRelease: true)
        e.reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.history.count, 1)
        XCTAssertTrue(s.history[0].protectedSuccess)
    }

    func testCodableRelaunchPreservesProgress() throws {
        var s = protected()
        let e = engine("2026-10-03T12:00:00Z")
        try e.startMorning(&s, shieldApplied: true)
        try e.startTask(&s)
        var relaunched = try JSONDecoder().decode(ResetState.self, from: JSONEncoder().encode(s))
        engine("2026-10-03T12:04:00Z").reconcile(&relaunched, mayRelease: true)
        XCTAssertEqual(relaunched.session?.phase, .awaitingConfirmation)
        XCTAssertEqual(relaunched.session?.taskIndex, 0)
        XCTAssertEqual(relaunched.session?.taskDeadline, s.session?.taskDeadline)
    }

    func testBypassAfterDeadlineDoesNotCreditSuccess() throws {
        var s = try waiting()
        engine("2026-10-03T12:20:00Z").bypass(&s)
        XCTAssertEqual(s.session?.phase, .bypassed)
        XCTAssertEqual(s.protection?.active, false)
        XCTAssertFalse(s.history[0].protectedSuccess)
        engine("2026-10-03T12:21:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.history.count, 1)
    }

    func testDemoAndPrototypeDoNotCountAsProtectedSuccess() throws {
        for (demo, prototype) in [(true, false), (false, true)] {
            var s = try waiting(demo: demo, prototype: prototype)
            engine("2026-10-03T12:11:00Z").reconcile(&s, mayRelease: true)
            XCTAssertEqual(s.session?.phase, .released)
            XCTAssertFalse(s.history[0].protectedSuccess)
            if demo { XCTAssertEqual(s.protection?.active, true) }
        }
    }

    func testNewNightInterruptsOldWaitBeforeReleasing() throws {
        var s = try waiting("2026-10-04T03:25:00Z") // 22:25 Chicago
        s.scheduleEnabled = true
        s.lastHandledNight = date("2026-10-03T03:30:00Z")
        let oldID = s.protection?.id
        engine("2026-10-04T03:40:00Z").reconcile(&s, mayRelease: true)
        XCTAssertNotEqual(s.protection?.id, oldID)
        XCTAssertEqual(s.session?.phase, .interrupted)
        XCTAssertEqual(s.protection?.active, true)
        XCTAssertFalse(s.history[0].protectedSuccess)
        engine("2026-10-04T04:00:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.protection?.active, true)
        XCTAssertEqual(s.history.count, 1)
    }

    func testRevokedAccessPermanentlyDisqualifiesSession() throws {
        var s = try waiting()
        s.accessAvailable = false
        engine("2026-10-03T12:03:00Z").reconcile(&s, mayRelease: false)
        s.accessAvailable = true
        engine("2026-10-03T12:11:00Z").reconcile(&s, mayRelease: true)
        XCTAssertFalse(s.history[0].protectedSuccess)
    }

    func testEmptyRoutineAndMissingShieldRejected() {
        var s = protected()
        s.routine = []
        XCTAssertThrowsError(try engine("2026-10-03T12:00:00Z").startMorning(&s, shieldApplied: true))
        s.routine = RoutineTask.defaults
        XCTAssertThrowsError(try engine("2026-10-03T12:00:00Z").startMorning(&s))
    }

    func testMidnightKeepsDateAtWakeTap() throws {
        var s = try waiting("2026-10-04T04:59:00Z") // 23:59 Oct 3
        engine("2026-10-04T05:15:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.history[0].localDate, "2026-10-03")
        XCTAssertTrue(s.history[0].protectedSuccess)
    }

    func testAtMostOneSuccessPerDate() throws {
        var s = try waiting()
        engine("2026-10-03T12:11:00Z").reconcile(&s, mayRelease: true)
        engine("2026-10-03T13:00:00Z").beginProtection(&s, at: date("2026-10-03T13:00:00Z"), prototype: false)
        let e = engine("2026-10-03T13:00:00Z")
        try e.startMorning(&s, shieldApplied: true)
        try e.startTask(&s)
        try engine("2026-10-03T13:00:15Z").confirmTask(&s)
        engine("2026-10-03T13:11:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.history.count, 2)
        XCTAssertEqual(s.history.filter(\.protectedSuccess).count, 1)
    }

    func testTonightOverrideDoesNotChangeUsualLock() {
        var s = protected()
        s.tonightOverride = TonightOverride(dateKey: "2026-10-03", time: LockTime(hour: 23, minute: 0))
        XCTAssertEqual(CalendarRules.nextNight(in: s, at: date("2026-10-04T03:45:00Z"), calendar: calendar), date("2026-10-04T04:00:00Z"))
        XCTAssertEqual(CalendarRules.nextNight(in: s, at: date("2026-10-04T04:01:00Z"), calendar: calendar), date("2026-10-05T03:30:00Z"))
        XCTAssertEqual(s.lockTime, LockTime())
    }

    func testDaylightSavingScheduleAndWaitUseCorrectArithmetic() throws {
        var s = ResetState()
        s.lockTime = LockTime(hour: 2, minute: 30)
        let spring = CalendarRules.night(on: date("2026-03-08T12:00:00Z"), time: s.lockTime, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: spring), 3)
        let fall = CalendarRules.night(on: date("2026-11-01T12:00:00Z"), time: LockTime(hour: 1, minute: 30), calendar: calendar)
        XCTAssertEqual(fall, date("2026-11-01T06:30:00Z"))
        let wait = try waiting("2026-03-08T07:59:00Z")
        XCTAssertEqual(wait.session!.unlockDeadline!.timeIntervalSince(wait.session!.taskDeadline ?? date("2026-03-08T07:59:15Z")), 600)
    }

    func testTimeZoneTravelRetainsOriginalSessionDate() throws {
        var s = try waiting("2026-10-04T04:59:00Z")
        let tokyo = CalendarRules.localCalendar(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        RoutineEngine(clock: FixedClock(now: date("2026-10-04T05:20:00Z")), calendar: tokyo).reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.history[0].localDate, "2026-10-03")
        XCTAssertEqual(s.history[0].timeZoneID, "America/Chicago")
    }

    func testRetiredMonitorCannotApplyAnOldUnlockOrChangeAccess() throws {
        var s = try waiting()
        s.scheduleEnabled = true
        s.monitorName = "nightly.current"
        s.lastHandledNight = date("2026-10-03T03:30:00Z")
        let before = s
        let accepted = engine("2026-10-04T04:00:00Z").handleMonitorEvent(&s, name: "nightly.retired",
            accessAvailable: false, selectedApps: 0)
        XCTAssertFalse(accepted)
        XCTAssertEqual(s, before)
        XCTAssertTrue(engine("2026-10-04T04:00:00Z").handleMonitorEvent(&s, name: "nightly.current",
            accessAvailable: true, selectedApps: 1))
        XCTAssertEqual(s.session?.phase, .interrupted)
        XCTAssertEqual(s.protection?.active, true)
    }

    func testScheduleChangeReconcilesNewLockWithoutClearingCurrentProtection() throws {
        var s = try waiting()
        s.scheduleEnabled = true
        s.lastHandledNight = date("2026-10-03T03:30:00Z")
        s.lockTime = LockTime(hour: 8, minute: 0)
        engine("2026-10-03T13:05:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.protection?.startedAt, date("2026-10-03T13:00:00Z"))
        XCTAssertEqual(s.session?.phase, .interrupted)
        XCTAssertEqual(s.protection?.active, true)
        s.scheduleEnabled = false
        engine("2026-10-04T14:00:00Z").reconcile(&s, mayRelease: true)
        XCTAssertEqual(s.protection?.active, true)
    }
}

import Foundation
#if !CORE_TEST_RUNNER
import XCTest
#if XCODE_TEST_TARGET
@testable import MorningReset
#else
@testable import MorningResetCore
#endif
#endif

final class ShortcutRedirectTests: XCTestCase {
    var calendar: Calendar { CalendarRules.localCalendar(timeZone: TimeZone(identifier: "America/Chicago")!) }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func redirect(_ time: String) -> ShortcutRedirectEngine {
        ShortcutRedirectEngine(clock: FixedClock(now: date(time)), calendar: calendar)
    }
    func routine(_ time: String) -> RoutineEngine {
        RoutineEngine(clock: FixedClock(now: date(time)), calendar: calendar)
    }
    func configured(_ time: String = "2026-10-03T12:00:00Z") -> ResetState {
        var state = ResetState()
        state.onboardingComplete = true
        state.routine = [RoutineTask(title: "Water", duration: 15)]
        redirect(time).confirmSetup(&state)
        return state
    }
    func waiting(_ time: String = "2026-10-03T12:00:00Z") throws -> ResetState {
        var state = configured(time)
        try redirect(time).startMorning(&state)
        try routine(time).startTask(&state)
        let later = RoutineEngine(clock: FixedClock(now: date(time).addingTimeInterval(15)), calendar: calendar)
        try later.confirmTask(&state)
        return state
    }

    func testSetupDoesNotRetroactivelyRedirectAndNightPersistsAcrossMidnight() {
        var state = configured()
        XCTAssertFalse(redirect("2026-10-03T12:00:00Z").check(&state))
        XCTAssertFalse(redirect("2026-10-04T03:29:59Z").check(&state))
        XCTAssertTrue(redirect("2026-10-04T03:30:00Z").check(&state))
        let id = state.shortcutRedirect?.period?.id
        XCTAssertTrue(redirect("2026-10-04T12:00:00Z").check(&state))
        XCTAssertEqual(id, state.shortcutRedirect?.period?.id)
        XCTAssertNil(state.protection)
        XCTAssertFalse(state.accessAvailable)
    }

    func testDeadlineCheckStopsRedirectsWithoutOpeningAppAndNeverCreditsProtectedStreak() throws {
        var state = try waiting()
        XCTAssertTrue(redirect("2026-10-03T12:10:14Z").check(&state))
        XCTAssertFalse(redirect("2026-10-03T12:10:15Z").check(&state))
        XCTAssertEqual(state.session?.phase, .released)
        XCTAssertTrue(state.session?.isDemo == true)
        XCTAssertFalse(state.session?.eligible == true)
        XCTAssertFalse(state.history[0].protectedSuccess)
        XCTAssertFalse(redirect("2026-10-03T12:12:00Z").check(&state))
        XCTAssertEqual(state.history.count, 1)
    }

    func testNewNightWinsOverAnOldWaitAndNextMorningStartsFresh() throws {
        var state = try waiting("2026-10-04T03:25:00Z")
        let oldID = state.session?.redirectPeriodID
        XCTAssertTrue(redirect("2026-10-04T03:40:00Z").check(&state))
        XCTAssertNotEqual(state.shortcutRedirect?.period?.id, oldID)
        XCTAssertEqual(state.session?.phase, .interrupted)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertTrue(redirect("2026-10-04T12:00:00Z").check(&state))
        try redirect("2026-10-04T12:00:00Z").startMorning(&state)
        XCTAssertEqual(state.session?.redirectPeriodID, state.shortcutRedirect?.period?.id)
        XCTAssertEqual(state.session?.phase, .taskReady)
    }

    func testBypassAtExpiredWaitAndNextNight() throws {
        var state = try waiting()
        redirect("2026-10-03T12:12:00Z").bypass(&state)
        XCTAssertFalse(redirect("2026-10-03T12:12:00Z").check(&state))
        XCTAssertEqual(state.history[0].outcome, .bypassed)
        XCTAssertTrue(state.history[0].isDemo)
        XCTAssertFalse(state.history[0].protectedSuccess)
        XCTAssertTrue(redirect("2026-10-04T03:30:00Z").check(&state))
        redirect("2026-10-04T03:31:00Z").bypass(&state)
        XCTAssertFalse(redirect("2026-10-04T03:32:00Z").check(&state))
        XCTAssertTrue(state.history.allSatisfy(\.isDemo))
    }

    func testSetupTestWorksBeforeOnboardingAndExpiresWithoutEnablingNightlyRedirects() {
        var state = ResetState()
        let e = redirect("2026-10-03T12:00:00Z")
        XCTAssertFalse(e.check(&state))
        e.startSetupTest(&state)
        XCTAssertTrue(e.check(&state))
        XCTAssertFalse(redirect("2026-10-03T12:01:00Z").check(&state))
        XCTAssertFalse(state.shortcutRedirect?.enabled == true)
        XCTAssertNil(state.shortcutRedirect?.period)
        XCTAssertTrue(state.history.isEmpty)
    }

    func testSuccessfulSetupCheckSurvivesExpiryAndLaterChecks() throws {
        var state = ResetState()
        let start = redirect("2026-10-03T12:00:00Z")
        start.startSetupTest(&state)
        XCTAssertFalse(state.shortcutRedirect!.canConfirmSetup)
        XCTAssertTrue(redirect("2026-10-03T12:00:10Z").check(&state))
        XCTAssertTrue(state.shortcutRedirect!.canConfirmSetup)
        let after = redirect("2026-10-03T12:01:00Z")
        XCTAssertFalse(after.check(&state))
        XCTAssertFalse(state.shortcutRedirect!.lastCheckWasTest == true)
        XCTAssertTrue(state.shortcutRedirect!.canConfirmSetup)
        state = try JSONDecoder().decode(ResetState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(state.shortcutRedirect!.canConfirmSetup)
        after.confirmSetup(&state)
        XCTAssertTrue(state.shortcutRedirect!.setupConfirmed)
        XCTAssertTrue(state.shortcutRedirect!.enabled)
        after.startSetupTest(&state)
        XCTAssertFalse(state.shortcutRedirect!.canConfirmSetup)
        XCTAssertFalse(redirect("2026-10-03T12:02:00Z").check(&state))
        XCTAssertFalse(state.shortcutRedirect!.canConfirmSetup)
        XCTAssertTrue(state.history.isEmpty)
    }

    func testPauseAndResumeDuringTaskPreservesTimer() throws {
        var state = configured()
        let e = redirect("2026-10-03T12:00:00Z")
        try e.startMorning(&state)
        try routine("2026-10-03T12:00:00Z").startTask(&state)
        let deadline = state.session?.taskDeadline
        e.setEnabled(false, in: &state)
        XCTAssertFalse(e.check(&state))
        e.setEnabled(true, in: &state)
        XCTAssertTrue(e.check(&state))
        XCTAssertEqual(state.session?.taskDeadline, deadline)
        XCTAssertEqual(state.session?.redirectPeriodID, state.shortcutRedirect?.period?.id)
    }

    func testRelaunchAndOldSchemaRemainReadable() throws {
        var state = try waiting()
        let data = try JSONEncoder().encode(state)
        state = try JSONDecoder().decode(ResetState.self, from: data)
        XCTAssertTrue(redirect("2026-10-03T12:05:00Z").check(&state))
        XCTAssertFalse(redirect("2026-10-03T12:11:00Z").check(&state))
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "shortcutRedirect")
        var session = json["session"] as! [String: Any]
        session.removeValue(forKey: "redirectPeriodID")
        json["session"] = session
        let old = try JSONDecoder().decode(ResetState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.shortcutRedirect)
        XCTAssertNil(old.session?.redirectPeriodID)
    }

    func testChangingNightTimeDoesNotReleaseAnActivePeriod() {
        var state = configured()
        XCTAssertTrue(redirect("2026-10-04T03:30:00Z").check(&state))
        let id = state.shortcutRedirect?.period?.id
        state.lockTime = LockTime(hour: 23, minute: 0)
        XCTAssertTrue(redirect("2026-10-04T03:45:00Z").check(&state))
        XCTAssertEqual(state.shortcutRedirect?.period?.id, id)
    }

    func testCalendarDSTAndTravelDoNotChangeSessionDate() throws {
        var state = configured("2026-03-07T12:00:00Z")
        state.lockTime = LockTime(hour: 2, minute: 30)
        XCTAssertFalse(redirect("2026-03-08T07:59:59Z").check(&state))
        XCTAssertTrue(redirect("2026-03-08T08:00:00Z").check(&state))
        try redirect("2026-03-08T08:01:00Z").startMorning(&state)
        let originalDate = state.session?.localDate
        let tokyo = CalendarRules.localCalendar(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let traveled = ShortcutRedirectEngine(clock: FixedClock(now: date("2026-03-08T08:02:00Z")), calendar: tokyo)
        XCTAssertTrue(traveled.check(&state))
        XCTAssertEqual(state.session?.localDate, originalDate)
    }
}

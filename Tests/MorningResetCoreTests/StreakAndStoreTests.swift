import Foundation
#if !CORE_TEST_RUNNER
import XCTest
#if XCODE_TEST_TARGET
@testable import MorningReset
#else
@testable import MorningResetCore
#endif
#endif

final class StreakAndStoreTests: XCTestCase {
    let calendar = CalendarRules.localCalendar(timeZone: TimeZone(identifier: "America/Chicago")!)
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    func success(_ key: String) -> HistoryEntry {
        let d = CalendarRules.date(from: key, calendar: calendar)!
        return HistoryEntry(id: UUID(), localDate: key, timeZoneID: calendar.timeZone.identifier,
                            startedAt: d, finishedAt: d, outcome: .released, protectedSuccess: true,
                            isDemo: false, isPrototype: false)
    }
    func testUnfinishedTodayPreservesYesterdayStreakAndMissedDayEndsIt() {
        let history = [success("2026-10-01"), success("2026-10-02")]
        XCTAssertEqual(StreakSummary.calculate(history: history, now: date("2026-10-03T12:00:00Z"), calendar: calendar).current, 2)
        let missed = StreakSummary.calculate(history: history, now: date("2026-10-04T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(missed.current, 0)
        XCTAssertEqual(missed.best, 2)
    }
    func testDuplicateDaysAndMorningWeekCount() {
        let h = [success("2026-10-02"), success("2026-10-03"), success("2026-10-03")]
        let result = StreakSummary.calculate(history: h, now: date("2026-10-03T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.best, 2)
        XCTAssertEqual(result.thisWeek, 2)
    }
    func testDSTConsecutiveDates() {
        for keys in [["2026-03-07", "2026-03-08", "2026-03-09"], ["2026-10-31", "2026-11-01", "2026-11-02"]] {
            let summary = StreakSummary.calculate(history: keys.map(success), now: success(keys.last!).finishedAt, calendar: calendar)
            XCTAssertEqual(summary.current, 3)
            XCTAssertEqual(summary.best, 3)
        }
    }
    func testStorePersistsBetweenInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try LockedStateStore(directory: directory)
        try first.transaction { $0.routine = [RoutineTask(title: "Custom", duration: 300)] }
        let second = try LockedStateStore(directory: directory)
        XCTAssertEqual(try second.read().routine[0].title, "Custom")
    }
    func testCorruptStateFailsWithoutOverwritingFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LockedStateStore(directory: directory)
        let url = directory.appendingPathComponent("state.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try store.read())
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
    func testCrossInstanceTransactionsDoNotLoseUpdates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stores = try (0..<8).map { _ in try LockedStateStore(directory: directory) }
        let errors = NSLock()
        var failures = 0
        DispatchQueue.concurrentPerform(iterations: 80) { index in
            do { try stores[index % stores.count].transaction { $0.selectionCount += 1 } }
            catch { errors.lock(); failures += 1; errors.unlock() }
        }
        XCTAssertEqual(failures, 0)
        XCTAssertEqual(try stores[0].read().selectionCount, 80)
    }
    func testThrowingTransactionDoesNotCommitOrApplySideEffects() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LockedStateStore(directory: directory)
        var applied = false
        XCTAssertThrowsError(try store.transaction(afterCommit: { _ in applied = true }) { state in
            state.selectionCount = 42
            throw RoutineError.emptyRoutine
        })
        XCTAssertFalse(applied)
        XCTAssertEqual(try store.read().selectionCount, 0)
    }

    func testRestrictionSideEffectSeesCommittedState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LockedStateStore(directory: directory)
        var persisted: ResetState?
        try store.transaction(afterCommit: { state in
            persisted = try? JSONDecoder().decode(ResetState.self,
                from: Data(contentsOf: directory.appendingPathComponent("state.json")))
            XCTAssertEqual(persisted, state)
        }) { state in
            state.protection = ProtectionPeriod(startedAt: Date(), active: false)
        }
        XCTAssertEqual(persisted?.protection?.active, false)
    }
}

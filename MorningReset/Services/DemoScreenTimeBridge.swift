#if MORNING_RESET_DEMO || MORNING_RESET_SHORTCUTS
import Foundation

/// The demo target excludes the real bridge and all Screen Time frameworks/extensions.
/// These results explicitly mean no protection, not simulated successful restrictions.
enum ScreenTimeBridge {
    static let authorized = false
    static func selectedAppCount(in state: ResetState) -> Int { 0 }
    static func shieldApplied(for state: ResetState) -> Bool { false }
    static func isRegistered(_ state: ResetState) -> Bool { false }
    static func finishMainAppCommit(_ state: ResetState) {}
    static func register(_ state: inout ResetState, now: Date, calendar: Calendar) throws {
        throw SetupError.demoUnavailable
    }
    static func disableSchedule(_ state: inout ResetState) {
        state.scheduleEnabled = false
        state.monitorName = nil
        state.overrideMonitorName = nil
    }
}
#endif

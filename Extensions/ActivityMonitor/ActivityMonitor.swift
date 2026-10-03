import DeviceActivity
import Foundation
import os

final class ActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reconcile(activity, event: "Interval start")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Never unlock at the end of an interval. Protection spans midnight until foreground release.
        reconcile(activity, event: "Interval end; shielding retained")
    }

    private func reconcile(_ activity: DeviceActivityName, event: String) {
        do {
            let store = try SharedEnvironment.makeStore()
            try store.transaction(afterCommit: ScreenTimeBridge.apply) { state in
                let selectedApps = ScreenTimeBridge.selectedAppCount(in: state)
                guard RoutineEngine().handleMonitorEvent(&state, name: activity.rawValue,
                    accessAvailable: ScreenTimeBridge.authorized,
                    selectedApps: selectedApps) else { return }
                state.log(event, at: Date())
            }
        } catch {
            // Leave any existing shield intact if storage cannot be read. Do not fabricate fresh state.
            Logger(subsystem: "MorningReset", category: "Monitor").error("Reconciliation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

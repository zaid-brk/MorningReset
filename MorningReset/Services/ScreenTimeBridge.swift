import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

enum ScreenTimeBridge {
    static let settings = ManagedSettingsStore(named: ManagedSettingsStore.Name("morningReset"))
    static var authorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }

    static func selection(in state: ResetState) -> FamilyActivitySelection {
        guard let data = state.selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func selectedAppCount(in state: ResetState) -> Int { selection(in: state).applicationTokens.count }

    static func apply(_ state: ResetState) {
        let tokens = selection(in: state).applicationTokens
        let active = state.protection?.active == true && state.accessAvailable && authorized && !tokens.isEmpty
        settings.shield.applications = active ? tokens : nil
    }

    static func shieldApplied(for state: ResetState) -> Bool {
        let expected = selection(in: state).applicationTokens
        return authorized && !expected.isEmpty && settings.shield.applications == expected
    }

    static func isRegistered(_ state: ResetState) -> Bool {
        guard state.scheduleEnabled, let name = state.monitorName else { return false }
        let activities = DeviceActivityCenter().activities
        guard activities.contains(DeviceActivityName(name)) else { return false }
        let calendar = CalendarRules.localCalendar()
        if let adjustment = state.tonightOverride,
           let day = CalendarRules.date(from: adjustment.dateKey, calendar: calendar),
           CalendarRules.night(on: day, time: adjustment.time, calendar: calendar) > Date() {
            guard let overrideName = state.overrideMonitorName else { return false }
            return activities.contains(DeviceActivityName(overrideName))
        }
        return true
    }

    /// Install before retiring previous names; if installation fails, keep the existing configuration.
    static func register(_ state: inout ResetState, now: Date, calendar: Calendar) throws {
        guard authorized else { throw SetupError.permission }
        let center = DeviceActivityCenter()
        let name = "nightly.\(UUID().uuidString)"
        let time = state.lockTime
        // A 12-hour monitoring window is safely above Apple's 15-minute minimum, even around DST.
        // Its end callback NEVER unlocks apps; the window exists only to deliver nightly starts.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: time.hour, minute: time.minute),
            intervalEnd: DateComponents(hour: (time.hour + 12) % 24, minute: time.minute), repeats: true)
        var installed = [DeviceActivityName(name)]
        var overrideName: String?
        do {
            try center.startMonitoring(DeviceActivityName(name), during: schedule)
            if let adjustment = state.tonightOverride,
               let day = CalendarRules.date(from: adjustment.dateKey, calendar: calendar) {
                let start = CalendarRules.night(on: day, time: adjustment.time, calendar: calendar)
                if start > now {
                    let end = start.addingTimeInterval(3600)
                    let specific = "tonight.\(UUID().uuidString)"
                    let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
                    let oneOff = DeviceActivitySchedule(intervalStart: calendar.dateComponents(components, from: start),
                        intervalEnd: calendar.dateComponents(components, from: end), repeats: false)
                    installed.append(DeviceActivityName(specific))
                    try center.startMonitoring(DeviceActivityName(specific), during: oneOff)
                    overrideName = specific
                }
            }
        } catch {
            center.stopMonitoring(installed)
            throw error
        }
        state.monitorName = name
        state.overrideMonitorName = overrideName
        state.scheduleTimeZoneID = calendar.timeZone.identifier
        state.scheduleEnabled = true
        // Do not impose a retroactive previous-night lock when the user first enables the schedule.
        if state.lastHandledNight == nil { state.lastHandledNight = now }
        state.log("Nightly monitoring registered", at: now)
    }

    static func disableSchedule(_ state: inout ResetState) {
        state.scheduleEnabled = false
        state.monitorName = nil
        state.overrideMonitorName = nil
        // Existing protection remains until completion or the explicit escape option.
    }

    /// Retire old registrations only after state has been saved successfully.
    static func finishMainAppCommit(_ state: ResetState) {
        apply(state)
        let currentNames = Set([state.monitorName, state.overrideMonitorName].compactMap { $0 })
        let obsolete = DeviceActivityCenter().activities.filter {
            ($0.rawValue.hasPrefix("nightly.") || $0.rawValue.hasPrefix("tonight."))
                && !currentNames.contains($0.rawValue)
        }
        if !obsolete.isEmpty { DeviceActivityCenter().stopMonitoring(obsolete) }
    }
}

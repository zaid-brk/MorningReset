import Foundation

public struct ShortcutRedirectPeriod: Codable, Equatable, Sendable {
    public var id = UUID()
    public var startedAt: Date
    public var active = true
}

public struct ShortcutRedirectSettings: Codable, Equatable, Sendable {
    public var enabled = false
    /// The user's confirmation, never proof that an iOS automation remains installed.
    public var setupConfirmed = false
    public var lastHandledNight: Date?
    public var period: ShortcutRedirectPeriod?
    public var testDeadline: Date?
    public var lastCheckAt: Date?
    public var lastCheckRequestedRedirect: Bool?
    public var lastCheckWasTest: Bool?
    /// A successful check for the current setup attempt survives later checks and test expiry.
    public var successfulTestCheckAt: Date?
    public var canConfirmSetup: Bool {
        successfulTestCheckAt != nil || (lastCheckWasTest == true && lastCheckRequestedRedirect == true)
    }
    public init() {}
}

/// Evaluated on app entry and on each Shortcuts invocation. No background timer is required.
/// These sessions are nonprotected routines and never earn Screen Time streak credit.
public struct ShortcutRedirectEngine {
    public let clock: any ResetClock
    public var calendar: Calendar
    private var routine: RoutineEngine { RoutineEngine(clock: clock, calendar: calendar) }

    public init(clock: any ResetClock = SystemClock(), calendar: Calendar = CalendarRules.localCalendar()) {
        self.clock = clock
        self.calendar = calendar
    }

    public func setEnabled(_ enabled: Bool, in state: inout ResetState) {
        var settings = state.shortcutRedirect ?? ShortcutRedirectSettings()
        if enabled && !settings.enabled {
            // Enabling never retroactively starts last night's period.
            settings.lastHandledNight = clock.now
            if state.session?.isFinished == false {
                settings.period = ShortcutRedirectPeriod(startedAt: clock.now)
                state.session?.redirectPeriodID = settings.period?.id
            }
        }
        settings.enabled = enabled
        if !enabled {
            settings.period?.active = false
            settings.testDeadline = nil
        }
        state.shortcutRedirect = settings
    }

    public func reconcile(_ state: inout ResetState) {
        var settings = state.shortcutRedirect ?? ShortcutRedirectSettings()
        updateNight(&state, settings: &settings)
        if let deadline = settings.testDeadline, clock.now >= deadline { settings.testDeadline = nil }
        // Only the matching routine may release a redirect period; a newer night always wins.
        routine.reconcile(&state, mayRelease: true)
        if let session = state.session, session.redirectPeriodID == settings.period?.id,
           session.phase == .released || session.phase == .bypassed {
            settings.period?.active = false
        }
        state.shortcutRedirect = settings
    }

    private func updateNight(_ state: inout ResetState, settings: inout ShortcutRedirectSettings) {
        if settings.enabled {
            let due = CalendarRules.latestNight(in: state, at: clock.now, calendar: calendar)
            if let last = settings.lastHandledNight, due > last {
                routine.interruptSession(&state)
                settings.period = ShortcutRedirectPeriod(startedAt: due)
                settings.lastHandledNight = due
                state.log("New voluntary redirect period", at: clock.now)
            } else if settings.lastHandledNight == nil {
                settings.lastHandledNight = clock.now
            }
        }
    }

    public func startMorning(_ state: inout ResetState) throws {
        reconcile(&state)
        // Validate before creating a new redirect period.
        try routine.startMorning(&state, demo: true)
        var settings = state.shortcutRedirect ?? ShortcutRedirectSettings()
        if settings.enabled {
            if settings.period?.active != true {
                settings.period = ShortcutRedirectPeriod(startedAt: clock.now)
            }
            state.session?.redirectPeriodID = settings.period?.id
        }
        state.shortcutRedirect = settings
    }

    public func bypass(_ state: inout ResetState) {
        // Preserve the ordinary bypass rule: don't credit an expired wait first.
        var settings = state.shortcutRedirect ?? ShortcutRedirectSettings()
        updateNight(&state, settings: &settings)
        routine.bypass(&state)
        state.session?.isDemo = true
        state.session?.eligible = false
        state.session?.redirectPeriodID = settings.period?.id
        if let id = state.session?.id, let index = state.history.firstIndex(where: { $0.id == id }) {
            state.history[index].isDemo = true
        }
        settings.period?.active = false
        settings.testDeadline = nil
        state.shortcutRedirect = settings
    }

    public func startSetupTest(_ state: inout ResetState) {
        // A test expires on its own. It does not create a protected or nightly period.
        state.shortcutRedirect = state.shortcutRedirect ?? ShortcutRedirectSettings()
        state.shortcutRedirect?.testDeadline = clock.now.addingTimeInterval(60)
        state.shortcutRedirect?.lastCheckAt = nil
        state.shortcutRedirect?.lastCheckRequestedRedirect = nil
        state.shortcutRedirect?.lastCheckWasTest = nil
        state.shortcutRedirect?.successfulTestCheckAt = nil
    }

    public func confirmSetup(_ state: inout ResetState) {
        setEnabled(true, in: &state)
        state.shortcutRedirect?.setupConfirmed = true
        state.shortcutRedirect?.testDeadline = nil
    }

    /// The Shortcuts automation uses this Boolean in an If action, then opens Morning Reset.
    public func check(_ state: inout ResetState) -> Bool {
        reconcile(&state)
        state.shortcutRedirect?.lastCheckAt = clock.now
        let settings = state.shortcutRedirect ?? ShortcutRedirectSettings()
        let isTest = settings.testDeadline.map { clock.now < $0 } == true
        let requested = isTest || (state.onboardingComplete && settings.enabled && settings.period?.active == true)
        state.shortcutRedirect?.lastCheckWasTest = isTest
        state.shortcutRedirect?.lastCheckRequestedRedirect = requested
        if isTest && requested { state.shortcutRedirect?.successfulTestCheckAt = clock.now }
        return requested
    }
}

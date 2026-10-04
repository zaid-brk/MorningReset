#if MORNING_RESET_SHORTCUTS
import AppIntents
import Foundation

struct CheckMorningRedirectIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Morning Redirect"
    static var description = IntentDescription("Returns Yes while your nightly routine or ten-minute pause is unfinished. Use If with this result, then Open App → Morning Reset Shortcuts.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        // This intent belongs to the app, not an extension. It uses the same local
        // sandbox and file lock as AppModel without constructing any UI or archive.
        let store = try SharedEnvironment.makeStore()
        let needsRedirect = try store.transaction { state in
            state.scheduleEnabled = false
            state.protection = nil
            state.accessAvailable = false
            state.selectionCount = 0
            return ShortcutRedirectEngine().check(&state)
        }
        return .result(value: needsRedirect)
    }
}

struct MorningResetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CheckMorningRedirectIntent(),
                    phrases: ["Check my morning redirect with \(.applicationName)"],
                    shortTitle: "Check Morning Redirect", systemImageName: "sun.horizon")
    }
}
#endif

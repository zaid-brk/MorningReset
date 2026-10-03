import Foundation

enum BuildMode {
    #if MORNING_RESET_DEMO
    static let isDemo = true
    #else
    static let isDemo = false
    #endif
}

enum SharedEnvironment {
    static func makeStore() throws -> LockedStateStore {
        let container: URL
        #if MORNING_RESET_DEMO
        // The free demo has its own app sandbox and never requests an App Group.
        container = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true)
        #else
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "MorningResetAppGroup") as? String,
              let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SetupError.appGroup
        }
        container = shared
        #endif
        let directory = container.appendingPathComponent("MorningReset", isDirectory: true)
        let store = try LockedStateStore(directory: directory)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                              ofItemAtPath: directory.path)
        return store
    }
}

enum SetupError: LocalizedError {
    case appGroup, permission, pastOverride, demoUnavailable
    var errorDescription: String? {
        switch self {
        case .appGroup: return "Shared storage is unavailable. Check that the app and both extensions use the same registered App Group and signing team."
        case .permission: return "Screen Time access is unavailable. Tap Restore Screen Time access, approve the request, then enable the nightly schedule."
        case .pastOverride: return "Choose a time later today for tonight’s adjustment."
        case .demoUnavailable: return "This demo tests your routine and timers. App blocking is available only in the full Screen Time build."
        }
    }
}

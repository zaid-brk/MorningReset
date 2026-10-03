import Foundation

public struct RoutineTask: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var duration: TimeInterval

    public init(id: UUID = UUID(), title: String, duration: TimeInterval) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.duration = max(15, duration.isFinite ? duration : 15)
    }

    public static let defaults = [
        RoutineTask(title: "10 push-ups", duration: 30),
        RoutineTask(title: "Brush teeth", duration: 120),
        RoutineTask(title: "Use the bathroom", duration: 60)
    ]
}

public struct LockTime: Codable, Equatable, Sendable {
    public var hour: Int
    public var minute: Int
    public init(hour: Int = 22, minute: Int = 30) {
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }
}

public struct TonightOverride: Codable, Equatable, Sendable {
    public var dateKey: String
    public var time: LockTime
    public init(dateKey: String, time: LockTime) { self.dateKey = dateKey; self.time = time }
}

public enum SessionPhase: String, Codable, Sendable {
    case taskReady, taskRunning, awaitingConfirmation, waitingToUnlock, released, bypassed, interrupted
}

public struct MorningSession: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var localDate: String
    public var timeZoneID: String
    public var startedAt: Date
    public var tasks: [RoutineTask]
    public var taskIndex = 0
    public var phase: SessionPhase = .taskReady
    public var taskDeadline: Date?
    public var unlockDeadline: Date?
    public var protectionID: UUID?
    public var eligible: Bool
    public var isDemo: Bool
    public var isPrototype: Bool
    public var successRecorded = false

    public var isFinished: Bool { [.released, .bypassed, .interrupted].contains(phase) }
    public var currentTask: RoutineTask? { tasks.indices.contains(taskIndex) ? tasks[taskIndex] : nil }
}

public struct ProtectionPeriod: Codable, Equatable, Sendable {
    public var id = UUID()
    public var startedAt: Date
    public var active = true
    public var isPrototype = false
}

public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var localDate: String
    public var timeZoneID: String
    public var startedAt: Date
    public var finishedAt: Date
    public var outcome: SessionPhase
    public var protectedSuccess: Bool
    public var isDemo: Bool
    public var isPrototype: Bool
}

public struct ResetState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var routine = RoutineTask.defaults
    public var lockTime = LockTime()
    public var tonightOverride: TonightOverride?
    public var onboardingComplete = false
    public var scheduleEnabled = false
    public var monitorName: String?
    public var overrideMonitorName: String?
    public var scheduleTimeZoneID: String?
    public var lastHandledNight: Date?
    public var selectionData: Data?
    public var selectionCount = 0
    public var accessAvailable = false
    public var notificationsEnabled = false
    public var protection: ProtectionPeriod?
    public var session: MorningSession?
    public var history: [HistoryEntry] = []
    public var diagnostics: [String] = []
    public init() {}

    public mutating func log(_ message: String, at date: Date) {
        diagnostics.append("\(ISO8601DateFormatter().string(from: date)) · \(message)")
        diagnostics = Array(diagnostics.suffix(60))
    }
}

public protocol ResetClock { var now: Date { get } }
public struct SystemClock: ResetClock { public init() {}; public var now: Date { Date() } }
public struct FixedClock: ResetClock { public var now: Date; public init(now: Date) { self.now = now } }

public enum RoutineError: LocalizedError, Equatable {
    case emptyRoutine, wrongPhase, timerNotFinished, protectionUnavailable, activeSession
    public var errorDescription: String? {
        switch self {
        case .emptyRoutine: return "Add at least one task with a title before starting."
        case .wrongPhase: return "This action is not available at this step."
        case .timerNotFinished: return "Let the task timer finish before confirming."
        case .protectionUnavailable: return "A protected night and Screen Time access are required. You can try a clearly labeled demo instead."
        case .activeSession: return "Finish or bypass the current session first."
        }
    }
}

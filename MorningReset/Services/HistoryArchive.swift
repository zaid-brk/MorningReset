import Foundation
import SwiftData

@Model
final class ArchivedMorning {
    @Attribute(.unique) var sessionID: UUID
    var localDate: String
    var timeZoneID: String
    var startedAt: Date
    var finishedAt: Date
    var outcome: String
    var protectedSuccess: Bool
    var isDemo: Bool
    var isPrototype: Bool

    init(entry: HistoryEntry) {
        sessionID = entry.id; localDate = entry.localDate; timeZoneID = entry.timeZoneID
        startedAt = entry.startedAt; finishedAt = entry.finishedAt; outcome = entry.outcome.rawValue
        protectedSuccess = entry.protectedSuccess; isDemo = entry.isDemo; isPrototype = entry.isPrototype
    }
}

/// The App Group state is authoritative. SwiftData is a main-app local history mirror,
/// so extensions never open a SwiftData store or race its writes.
@MainActor
final class HistoryArchive {
    private let container: ModelContainer
    init() throws { container = try ModelContainer(for: ArchivedMorning.self) }

    func sync(_ entries: [HistoryEntry]) throws {
        let context = container.mainContext
        let existing = Set(try context.fetch(FetchDescriptor<ArchivedMorning>()).map(\.sessionID))
        for entry in entries where !existing.contains(entry.id) { context.insert(ArchivedMorning(entry: entry)) }
        if context.hasChanges { try context.save() }
    }
}

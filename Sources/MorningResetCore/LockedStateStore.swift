import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// An atomic JSON file plus a separate flock file serialize app/extension read-modify-write operations.
/// The lock covers shield writes too: callers must apply restrictions inside the transaction closure.
public final class LockedStateStore {
    public let directory: URL
    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func read() throws -> ResetState { try transaction { $0 } }

    @discardableResult
    public func transaction<T>(afterCommit: ((ResetState) -> Void)? = nil,
                               _ body: (inout ResetState) throws -> T) throws -> T {
        let lockPath = directory.appendingPathComponent("state.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(descriptor, LOCK_UN) }
        let url = directory.appendingPathComponent("state.json")
        var state: ResetState
        if FileManager.default.fileExists(atPath: url.path) {
            // Never reset a corrupt file silently: that could clear protection or duplicate history credit.
            state = try JSONDecoder().decode(ResetState.self, from: Data(contentsOf: url))
            guard state.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        } else {
            state = ResetState()
        }
        let result = try body(&state)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                              ofItemAtPath: url.path)
        #endif
        afterCommit?(state)
        return result
    }
}

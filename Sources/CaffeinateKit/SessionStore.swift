import Foundation

/// A session written to disk so it can survive a crash or a force quit.
///
/// Without this, a `caffeinate` process orphaned by an app crash would keep the
/// Mac awake forever with nothing left in the UI to stop it.
public struct PersistedSession: Codable, Equatable, Sendable {
    public var pid: Int32
    public var startDate: Date
    public var duration: SessionDuration
    public var options: CaffeinateOptions

    public init(pid: Int32, startDate: Date, duration: SessionDuration, options: CaffeinateOptions) {
        self.pid = pid
        self.startDate = startDate
        self.duration = duration
        self.options = options
    }
}

public protocol SessionPersisting: AnyObject {
    func save(_ session: PersistedSession?)
    func load() -> PersistedSession?
}

/// Stores the active session in
/// `~/Library/Application Support/CaffeinateUI/session.json`.
public final class FileSessionStore: SessionPersisting {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let base = directory ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("CaffeinateUI", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CaffeinateUI")
        fileURL = base.appendingPathComponent("session.json")
    }

    public func save(_ session: PersistedSession?) {
        guard let session else {
            try? fileManager.removeItem(at: fileURL)
            return
        }
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(session).write(to: fileURL, options: .atomic)
        } catch {
            // Losing the breadcrumb is not worth interrupting the user over.
            Log.warning("Could not persist session: \(error.localizedDescription)")
        }
    }

    public func load() -> PersistedSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedSession.self, from: data)
    }
}

/// In-memory store, used by the tests.
public final class InMemorySessionStore: SessionPersisting {
    public private(set) var stored: PersistedSession?

    public init(stored: PersistedSession? = nil) {
        self.stored = stored
    }

    public func save(_ session: PersistedSession?) { stored = session }
    public func load() -> PersistedSession? { stored }
}

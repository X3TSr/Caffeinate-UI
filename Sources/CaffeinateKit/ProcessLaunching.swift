import Foundation

/// A launched child process, narrowed to what the controller actually needs.
public protocol LaunchedProcess: AnyObject {
    var processIdentifier: Int32 { get }
    var isRunning: Bool { get }
    func terminate()
}

/// Indirection over `Foundation.Process` so the controller can be tested
/// without spawning anything.
public protocol ProcessLaunching: AnyObject {
    /// Launches `executable` with `arguments`.
    /// - Parameter onExit: called on an arbitrary queue when the process ends.
    func launch(
        executable: URL,
        arguments: [String],
        onExit: @escaping (Int32) -> Void
    ) throws -> LaunchedProcess

    /// Cheap liveness check, safe to call every second.
    func isProcessAlive(pid: Int32) -> Bool

    /// True when a process with `pid` is alive and is actually `caffeinate`.
    /// Used to recover a session that outlived a previous run of the app.
    /// More expensive than `isProcessAlive`, so only called at launch.
    func isCaffeinateProcess(pid: Int32) -> Bool

    /// Sends SIGTERM to a process this launcher did not spawn.
    func terminateProcess(pid: Int32)
}

public enum CaffeinateError: LocalizedError, Equatable {
    case caffeinateNotFound
    case noAssertionsSelected
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .caffeinateNotFound:
            return "Could not find \(CaffeinateCommand.executablePath) on this Mac."
        case .noAssertionsSelected:
            return "Select at least one thing to keep awake."
        case let .launchFailed(reason):
            return "Could not start caffeinate: \(reason)"
        }
    }
}

// MARK: - System implementation

final class SystemProcess: LaunchedProcess {
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    var processIdentifier: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }

    func terminate() {
        guard process.isRunning else { return }
        process.terminate()
    }
}

/// Launches real processes with `Foundation.Process`.
public final class SystemProcessLauncher: ProcessLaunching {
    public init() {}

    public func launch(
        executable: URL,
        arguments: [String],
        onExit: @escaping (Int32) -> Void
    ) throws -> LaunchedProcess {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        // caffeinate is silent; detaching the pipes keeps it from inheriting
        // (and blocking on) our stdio.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        process.terminationHandler = { finished in
            onExit(finished.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            throw CaffeinateError.launchFailed(error.localizedDescription)
        }
        return SystemProcess(process: process)
    }

    public func isProcessAlive(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        // ESRCH means "no such process"; EPERM means it exists but is not ours,
        // which still counts as alive.
        return kill(pid, 0) == 0 || errno == EPERM
    }

    public func isCaffeinateProcess(pid: Int32) -> Bool {
        guard isProcessAlive(pid: pid) else { return false }
        // `kill(pid, 0)` only proves *something* is there; PIDs get recycled,
        // so confirm the executable name before we adopt or kill it.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let command = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return command == CaffeinateCommand.executablePath || command == "caffeinate"
        } catch {
            return false
        }
    }

    public func terminateProcess(pid: Int32) {
        guard pid > 0 else { return }
        kill(pid, SIGTERM)
    }
}

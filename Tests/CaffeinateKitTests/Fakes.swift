@testable import CaffeinateKit
import Foundation

/// A process that never really runs, so the controller can be tested without
/// keeping the test machine awake.
final class FakeProcess: LaunchedProcess {
    let processIdentifier: Int32
    private(set) var isRunning: Bool = true
    private let onExit: (Int32) -> Void

    init(pid: Int32, onExit: @escaping (Int32) -> Void) {
        processIdentifier = pid
        self.onExit = onExit
    }

    func terminate() {
        guard isRunning else { return }
        isRunning = false
        onExit(SIGTERM)
    }

    /// Simulates `caffeinate -t` reaching the end of its timeout.
    func finishNaturally() {
        guard isRunning else { return }
        isRunning = false
        onExit(0)
    }
}

/// A clock the tests can move by hand. Deliberately not actor isolated so the
/// controller can read it from its timer callback.
final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

final class FakeLauncher: ProcessLaunching {
    struct Launch: Equatable {
        let executable: URL
        let arguments: [String]
    }

    private(set) var launches: [Launch] = []
    private(set) var processes: [FakeProcess] = []
    private(set) var terminatedPIDs: [Int32] = []

    /// PIDs that `isProcessAlive` should report as running.
    var alivePIDs: Set<Int32> = []
    /// PIDs that `isCaffeinateProcess` should recognise.
    var caffeinatePIDs: Set<Int32> = []
    var nextPID: Int32 = 4242
    var launchError: Error?

    var lastProcess: FakeProcess? { processes.last }

    func launch(
        executable: URL,
        arguments: [String],
        onExit: @escaping (Int32) -> Void
    ) throws -> LaunchedProcess {
        if let launchError { throw launchError }
        launches.append(Launch(executable: executable, arguments: arguments))
        let process = FakeProcess(pid: nextPID, onExit: onExit)
        nextPID += 1
        processes.append(process)
        alivePIDs.insert(process.processIdentifier)
        return process
    }

    func isProcessAlive(pid: Int32) -> Bool {
        alivePIDs.contains(pid)
    }

    func isCaffeinateProcess(pid: Int32) -> Bool {
        caffeinatePIDs.contains(pid)
    }

    func terminateProcess(pid: Int32) {
        terminatedPIDs.append(pid)
        alivePIDs.remove(pid)
    }
}

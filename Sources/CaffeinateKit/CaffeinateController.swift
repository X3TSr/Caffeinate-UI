import Combine
import Foundation

/// A running session. `pid` is the `caffeinate` process keeping the Mac up.
public struct CaffeinateSession: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let pid: Int32
    public let startDate: Date
    public let duration: SessionDuration
    public let options: CaffeinateOptions
    /// True when the session was recovered from a previous run of the app
    /// rather than started by this one.
    public let isAdopted: Bool

    public var command: String {
        CaffeinateCommand.displayString(options: options, duration: duration)
    }

    public var endDate: Date? {
        duration.endDate(from: startDate)
    }
}

/// Why a session stopped. Drives whether a notification is posted.
public enum SessionEndReason: Equatable, Sendable {
    /// The user pressed Stop.
    case stopped
    /// The timer ran out and `caffeinate` exited on its own.
    case completed
    /// The process died unexpectedly (killed from Terminal, for example).
    case processExited
    /// The app is quitting.
    case appQuit
    /// Replaced by a new session, e.g. after changing the duration.
    case restarted
}

/// Owns the lifecycle of the `caffeinate` process and publishes everything the
/// UI needs to render: the running session, a one second tick for countdowns,
/// and the last error.
@MainActor
public final class CaffeinateController: ObservableObject {
    public typealias Session = CaffeinateSession
    public typealias EndReason = SessionEndReason

    @Published public private(set) var session: Session?
    /// Updated every second while a session runs, so views recompute countdowns.
    @Published public private(set) var tick: Date = Date()
    @Published public var lastError: CaffeinateError?

    /// Called after a session ends. The app uses it to post notifications.
    public var onSessionEnded: (@MainActor (Session, EndReason) -> Void)?

    private let launcher: ProcessLaunching
    private let store: SessionPersisting
    private let clock: () -> Date
    private var process: LaunchedProcess?
    private var timer: Timer?
    /// Bumped on every launch. Exit callbacks carry the generation they were
    /// created with, so the termination of a process we deliberately replaced
    /// cannot tear down the session that replaced it.
    private var generation = 0

    public init(
        launcher: ProcessLaunching = SystemProcessLauncher(),
        store: SessionPersisting = FileSessionStore(),
        clock: @escaping () -> Date = { Date() }
    ) {
        self.launcher = launcher
        self.store = store
        self.clock = clock
        tick = clock()
    }

    // MARK: - Derived state

    public var isActive: Bool { session != nil }

    /// Seconds until the session ends, or `nil` for indefinite / idle.
    public var remainingSeconds: Int? {
        guard let session, let total = session.duration.seconds else { return nil }
        let elapsed = tick.timeIntervalSince(session.startDate)
        return max(0, Int((Double(total) - elapsed).rounded(.up)))
    }

    public var elapsedSeconds: Int {
        guard let session else { return 0 }
        return max(0, Int(tick.timeIntervalSince(session.startDate)))
    }

    /// 0...1 for timed sessions, `nil` when idle or indefinite.
    public var progress: Double? {
        guard let session, let total = session.duration.seconds, total > 0 else { return nil }
        let elapsed = tick.timeIntervalSince(session.startDate)
        return min(1, max(0, elapsed / Double(total)))
    }

    public var endDate: Date? { session?.endDate }

    /// Countdown for the menu bar, e.g. "7:42:11" or "∞".
    public var countdownText: String? {
        guard session != nil else { return nil }
        guard let remaining = remainingSeconds else { return "∞" }
        return TimeFormatting.clock(seconds: remaining)
    }

    // MARK: - Actions

    /// Starts a session, replacing any session already running.
    @discardableResult
    public func start(options: CaffeinateOptions, duration: SessionDuration) -> Bool {
        guard !options.isEmpty else {
            lastError = .noAssertionsSelected
            return false
        }
        guard CaffeinateCommand.isAvailable else {
            lastError = .caffeinateNotFound
            return false
        }

        if session != nil {
            stop(reason: .restarted)
        }

        let arguments = CaffeinateCommand.arguments(options: options, duration: duration)
        generation += 1
        let launchGeneration = generation

        do {
            let started = clock()
            let launched = try launcher.launch(
                executable: CaffeinateCommand.executableURL,
                arguments: arguments
            ) { status in
                Task { @MainActor [weak self] in
                    self?.handleProcessExit(status: status, generation: launchGeneration)
                }
            }

            process = launched
            let newSession = Session(
                id: UUID(),
                pid: launched.processIdentifier,
                startDate: started,
                duration: duration,
                options: options,
                isAdopted: false
            )
            session = newSession
            lastError = nil
            store.save(
                PersistedSession(
                    pid: newSession.pid,
                    startDate: newSession.startDate,
                    duration: duration,
                    options: options
                )
            )
            startTicking()
            Log.info("Started \(newSession.command) (pid \(newSession.pid))")
            return true
        } catch let error as CaffeinateError {
            lastError = error
            Log.error("Launch failed: \(error.localizedDescription)")
            return false
        } catch {
            lastError = .launchFailed(error.localizedDescription)
            Log.error("Launch failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Stops the running session. No-op when idle.
    public func stop(reason: EndReason = .stopped) {
        guard let ending = session else { return }

        if let process, process.isRunning {
            process.terminate()
        } else if ending.isAdopted {
            launcher.terminateProcess(pid: ending.pid)
        }

        process = nil
        session = nil
        store.save(nil)
        stopTicking()
        Log.info("Stopped session (pid \(ending.pid)), reason: \(String(describing: reason))")
        onSessionEnded?(ending, reason)
    }

    /// Starts with the given settings when idle, stops when running.
    public func toggle(options: CaffeinateOptions, duration: SessionDuration) {
        if isActive {
            stop(reason: .stopped)
        } else {
            start(options: options, duration: duration)
        }
    }

    /// Pushes the end time out by `seconds`, keeping the current options.
    /// Indefinite sessions are left alone since they never end.
    public func extend(by seconds: Int) {
        guard let session, let remaining = remainingSeconds else { return }
        start(options: session.options, duration: .seconds(remaining + seconds))
    }

    /// Changes the duration of the running session, keeping its options.
    public func changeDuration(to duration: SessionDuration) {
        guard let session else { return }
        start(options: session.options, duration: duration)
    }

    /// Applies new options to the running session without changing when it ends.
    public func updateOptions(_ options: CaffeinateOptions) {
        guard isActive else { return }
        let duration: SessionDuration
        if let remaining = remainingSeconds {
            duration = .seconds(max(1, remaining))
        } else {
            duration = .indefinite
        }
        start(options: options, duration: duration)
    }

    /// Reattaches to a `caffeinate` process left behind by a previous run of the
    /// app (crash, force quit, logout). Call once at launch.
    /// - Returns: the recovered session, if there was one.
    @discardableResult
    public func recoverOrphanedSession() -> Session? {
        guard session == nil, let persisted = store.load() else { return nil }

        guard launcher.isCaffeinateProcess(pid: persisted.pid) else {
            store.save(nil)
            return nil
        }

        // A timed session may have finished while the app was gone.
        if let total = persisted.duration.seconds,
           clock().timeIntervalSince(persisted.startDate) >= Double(total) {
            launcher.terminateProcess(pid: persisted.pid)
            store.save(nil)
            return nil
        }

        let recovered = Session(
            id: UUID(),
            pid: persisted.pid,
            startDate: persisted.startDate,
            duration: persisted.duration,
            options: persisted.options,
            isAdopted: true
        )
        session = recovered
        startTicking()
        Log.info("Recovered orphaned session (pid \(recovered.pid))")
        return recovered
    }

    // MARK: - Ticking

    private func startTicking() {
        stopTicking()
        tick = clock()
        // Timer's block is @Sendable, so the weak capture belongs to the Task —
        // capturing it outside would make it a var read from concurrent code.
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }
        timer.tolerance = 0.1
        // .common keeps the countdown alive while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTick() {
        guard let session else {
            stopTicking()
            return
        }
        tick = clock()

        // Adopted sessions have no termination handler, so poll instead.
        if session.isAdopted, !launcher.isProcessAlive(pid: session.pid) {
            finish(reason: remainingSeconds == 0 ? .completed : .processExited)
            return
        }

        if let remaining = remainingSeconds, remaining <= 0, !session.isAdopted {
            // caffeinate -t exits on its own; if the handler has not fired
            // within a second, tidy up anyway.
            if let process, !process.isRunning {
                finish(reason: .completed)
            }
        }
    }

    private func handleProcessExit(status: Int32, generation: Int) {
        // A process we replaced on purpose must not end the session that
        // replaced it.
        guard generation == self.generation else { return }
        guard let session, !session.isAdopted else { return }
        // Refresh the clock first: the tick can be up to a second stale, which
        // would misreport a session that ended exactly on time.
        tick = clock()
        let reason: EndReason = (remainingSeconds ?? 1) <= 0 ? .completed : .processExited
        Log.info("caffeinate exited with status \(status)")
        finish(reason: reason)
    }

    /// Clears state for a session that ended on its own — nothing left to kill.
    private func finish(reason: EndReason) {
        guard let ending = session else { return }
        process = nil
        session = nil
        store.save(nil)
        stopTicking()
        onSessionEnded?(ending, reason)
    }
}

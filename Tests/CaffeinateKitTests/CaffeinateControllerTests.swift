@testable import CaffeinateKit
import XCTest

@MainActor
final class CaffeinateControllerTests: XCTestCase {
    private var launcher: FakeLauncher!
    private var store: InMemorySessionStore!
    private var clock: TestClock!

    /// Shorthand for "the current fake time".
    private var now: Date { clock.now }

    override func setUp() {
        super.setUp()
        launcher = FakeLauncher()
        store = InMemorySessionStore()
        clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func makeController() -> CaffeinateController {
        // Captured locally so the timer callback does not touch the test case.
        let clock = clock!
        return CaffeinateController(launcher: launcher, store: store, clock: { clock.now })
    }

    // MARK: - Starting

    func testStartLaunchesCaffeinateWithTheExpectedCommand() {
        let controller = makeController()
        XCTAssertTrue(controller.start(options: .standard, duration: .seconds(28800)))

        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches[0].executable.path, "/usr/bin/caffeinate")
        XCTAssertEqual(launcher.launches[0].arguments, ["-d", "-i", "-t", "28800"])
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.session?.command, "caffeinate -d -i -t 28800")
    }

    func testStartWithoutAssertionsFails() {
        let controller = makeController()
        let empty = CaffeinateOptions(preventDisplaySleep: false, preventIdleSleep: false)

        XCTAssertFalse(controller.start(options: empty, duration: .indefinite))
        XCTAssertEqual(controller.lastError, .noAssertionsSelected)
        XCTAssertTrue(launcher.launches.isEmpty)
        XCTAssertFalse(controller.isActive)
    }

    func testStartPersistsTheSessionForCrashRecovery() {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(3600))

        let persisted = try? XCTUnwrap(store.stored)
        XCTAssertEqual(persisted?.pid, controller.session?.pid)
        XCTAssertEqual(persisted?.duration, .seconds(3600))
        XCTAssertEqual(persisted?.options, .standard)
    }

    // MARK: - Stopping

    func testStopTerminatesTheProcessAndClearsState() {
        let controller = makeController()
        controller.start(options: .standard, duration: .indefinite)
        let process = try? XCTUnwrap(launcher.lastProcess)

        controller.stop()

        XCTAssertFalse(process?.isRunning ?? true)
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(store.stored)
    }

    func testStopReportsTheReasonToTheApp() {
        let controller = makeController()
        var reasons: [SessionEndReason] = []
        controller.onSessionEnded = { _, reason in reasons.append(reason) }

        controller.start(options: .standard, duration: .indefinite)
        controller.stop(reason: .appQuit)

        XCTAssertEqual(reasons, [.appQuit])
    }

    func testStopIsANoOpWhenIdle() {
        let controller = makeController()
        controller.stop()
        XCTAssertTrue(launcher.terminatedPIDs.isEmpty)
        XCTAssertFalse(controller.isActive)
    }

    // MARK: - Changing a running session

    func testChangingDurationRestartsWithTheNewTimeout() {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(3600))
        controller.changeDuration(to: .seconds(1800))

        XCTAssertEqual(launcher.launches.count, 2)
        XCTAssertEqual(launcher.launches[1].arguments, ["-d", "-i", "-t", "1800"])
        XCTAssertFalse(launcher.processes[0].isRunning, "the first process should be replaced")
        XCTAssertEqual(controller.session?.duration, .seconds(1800))
    }

    func testUpdatingOptionsKeepsTheRemainingTime() {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(3600))

        var options = CaffeinateOptions.standard
        options.preventDiskIdleSleep = true
        controller.updateOptions(options)

        XCTAssertEqual(launcher.launches[1].arguments, ["-d", "-i", "-m", "-t", "3600"])
    }

    func testExtendPushesTheEndTimeOut() {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(600))
        controller.extend(by: 900)

        XCTAssertEqual(launcher.launches[1].arguments, ["-d", "-i", "-t", "1500"])
    }

    /// Terminating the old process schedules an exit callback. It must not tear
    /// down the session that replaced it.
    func testReplacingASessionIgnoresTheReplacedProcessExit() async throws {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(3600))
        controller.changeDuration(to: .seconds(1800))

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(controller.isActive, "the new session should still be running")
        XCTAssertEqual(controller.session?.duration, .seconds(1800))
        XCTAssertEqual(controller.session?.pid, launcher.processes[1].processIdentifier)
    }

    func testExtendDoesNothingForIndefiniteSessions() {
        let controller = makeController()
        controller.start(options: .standard, duration: .indefinite)
        controller.extend(by: 900)

        XCTAssertEqual(launcher.launches.count, 1)
    }

    // MARK: - Derived state

    func testRemainingAndProgressAtTheStartOfASession() {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(1000))

        XCTAssertEqual(controller.remainingSeconds, 1000)
        XCTAssertEqual(controller.progress ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(controller.countdownText, "16:40")
    }

    func testIndefiniteSessionHasNoCountdown() {
        let controller = makeController()
        controller.start(options: .standard, duration: .indefinite)

        XCTAssertNil(controller.remainingSeconds)
        XCTAssertNil(controller.progress)
        XCTAssertEqual(controller.countdownText, "∞")
    }

    func testCountdownFollowsTheClock() async throws {
        let controller = makeController()
        controller.start(options: .standard, duration: .seconds(1000))
        clock.advance(by: 400)

        // The controller ticks once a second; give it one tick to catch up.
        try await Task.sleep(nanoseconds: 1_300_000_000)

        XCTAssertEqual(controller.remainingSeconds, 600)
        XCTAssertEqual(controller.progress ?? -1, 0.4, accuracy: 0.01)
    }

    // MARK: - Crash recovery

    func testRecoversASessionLeftRunningByAPreviousLaunch() {
        store = InMemorySessionStore(
            stored: PersistedSession(
                pid: 777,
                startDate: now.addingTimeInterval(-600),
                duration: .seconds(3600),
                options: .standard
            )
        )
        launcher.caffeinatePIDs = [777]
        launcher.alivePIDs = [777]

        let controller = makeController()
        let recovered = controller.recoverOrphanedSession()

        XCTAssertEqual(recovered?.pid, 777)
        XCTAssertTrue(controller.session?.isAdopted ?? false)
        XCTAssertEqual(controller.remainingSeconds, 3000)
    }

    func testRecoveryIgnoresAPIDThatIsNoLongerCaffeinate() {
        store = InMemorySessionStore(
            stored: PersistedSession(
                pid: 777,
                startDate: now,
                duration: .indefinite,
                options: .standard
            )
        )
        launcher.caffeinatePIDs = []

        let controller = makeController()

        XCTAssertNil(controller.recoverOrphanedSession())
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(store.stored, "the stale record should be cleared")
    }

    func testRecoveryStopsASessionWhoseTimeAlreadyElapsed() {
        store = InMemorySessionStore(
            stored: PersistedSession(
                pid: 777,
                startDate: now.addingTimeInterval(-7200),
                duration: .seconds(3600),
                options: .standard
            )
        )
        launcher.caffeinatePIDs = [777]
        launcher.alivePIDs = [777]

        let controller = makeController()

        XCTAssertNil(controller.recoverOrphanedSession())
        XCTAssertEqual(launcher.terminatedPIDs, [777])
        XCTAssertNil(store.stored)
    }

    func testStoppingAnAdoptedSessionKillsThePID() {
        store = InMemorySessionStore(
            stored: PersistedSession(
                pid: 777,
                startDate: now,
                duration: .indefinite,
                options: .standard
            )
        )
        launcher.caffeinatePIDs = [777]
        launcher.alivePIDs = [777]

        let controller = makeController()
        controller.recoverOrphanedSession()
        controller.stop()

        XCTAssertEqual(launcher.terminatedPIDs, [777])
        XCTAssertFalse(controller.isActive)
    }
}

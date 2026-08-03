@testable import CaffeinateKit
import XCTest

final class CaffeinateCommandTests: XCTestCase {
    func testDefaultOptionsProduceDisplayAndIdleFlags() {
        XCTAssertEqual(CaffeinateOptions.standard.flags, ["-d", "-i"])
    }

    func testFlagsAreEmittedInStableOrder() {
        let options = CaffeinateOptions(
            preventDisplaySleep: true,
            preventIdleSleep: true,
            preventDiskIdleSleep: true,
            preventSystemSleepOnAC: true,
            declareUserActive: true
        )
        XCTAssertEqual(options.flags, ["-d", "-i", "-m", "-s", "-u"])
    }

    func testTimedSessionAppendsTimeoutInSeconds() {
        let arguments = CaffeinateCommand.arguments(
            options: CaffeinateOptions(preventDisplaySleep: true, preventIdleSleep: false),
            duration: .seconds(28800)
        )
        XCTAssertEqual(arguments, ["-d", "-t", "28800"])
    }

    func testIndefiniteSessionOmitsTimeout() {
        let arguments = CaffeinateCommand.arguments(options: .standard, duration: .indefinite)
        XCTAssertEqual(arguments, ["-d", "-i"])
    }

    func testDisplayStringMatchesWhatYouWouldType() {
        let command = CaffeinateCommand.displayString(options: .standard, duration: .seconds(28800))
        XCTAssertEqual(command, "caffeinate -d -i -t 28800")
    }

    func testEmptyOptionsAreRejectable() {
        let none = CaffeinateOptions(
            preventDisplaySleep: false,
            preventIdleSleep: false,
            preventDiskIdleSleep: false,
            preventSystemSleepOnAC: false,
            declareUserActive: false
        )
        XCTAssertTrue(none.isEmpty)
        XCTAssertFalse(CaffeinateOptions.standard.isEmpty)
    }

    func testSummaryReadsAsSentenceCase() {
        XCTAssertEqual(CaffeinateOptions.standard.summary, "Display, system")
    }
}

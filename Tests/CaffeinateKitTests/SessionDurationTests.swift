@testable import CaffeinateKit
import XCTest

final class SessionDurationTests: XCTestCase {
    func testIndefiniteHasNoSeconds() {
        XCTAssertNil(SessionDuration.indefinite.seconds)
        XCTAssertTrue(SessionDuration.indefinite.isIndefinite)
        XCTAssertEqual(SessionDuration.indefinite.label, "Indefinite")
        XCTAssertEqual(SessionDuration.indefinite.shortLabel, "∞")
    }

    func testCustomDurationClampsToSupportedRange() {
        XCTAssertEqual(SessionDuration.custom(seconds: 5).seconds, SessionDuration.minimumCustomSeconds)
        XCTAssertEqual(
            SessionDuration.custom(seconds: 999_999).seconds,
            SessionDuration.maximumCustomSeconds
        )
        XCTAssertEqual(SessionDuration.custom(seconds: 5400).seconds, 5400)
    }

    func testLabels() {
        XCTAssertEqual(SessionDuration.seconds(8 * 3600).label, "8 hours")
        XCTAssertEqual(SessionDuration.seconds(5400).label, "1 hour 30 minutes")
        XCTAssertEqual(SessionDuration.seconds(900).shortLabel, "15m")
        XCTAssertEqual(SessionDuration.seconds(8 * 3600).shortLabel, "8h")
        XCTAssertEqual(SessionDuration.seconds(5400).shortLabel, "1h 30m")
    }

    func testEndDate() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(
            SessionDuration.seconds(600).endDate(from: start),
            start.addingTimeInterval(600)
        )
        XCTAssertNil(SessionDuration.indefinite.endDate(from: start))
    }

    func testRoundTripsThroughCodable() throws {
        for duration in SessionDuration.presets {
            let data = try JSONEncoder().encode(duration)
            XCTAssertEqual(try JSONDecoder().decode(SessionDuration.self, from: data), duration)
        }
    }

    func testClockFormatting() {
        XCTAssertEqual(TimeFormatting.clock(seconds: 27731), "7:42:11")
        XCTAssertEqual(TimeFormatting.clock(seconds: 61), "1:01")
        XCTAssertEqual(TimeFormatting.clock(seconds: -5), "0:00")
    }
}

@testable import CaffeinateKit
import XCTest

final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CaffeinateUITests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testShippedDefaults() {
        let preferences = Preferences(defaults: defaults)

        XCTAssertEqual(preferences.options, .standard)
        XCTAssertEqual(preferences.duration, .seconds(8 * 3600))
        XCTAssertTrue(preferences.notifyOnSessionEnd)
        XCTAssertTrue(preferences.showCountdownInMenuBar)
        XCTAssertFalse(preferences.startSessionOnLaunch)
        XCTAssertFalse(preferences.showDockIcon)
    }

    func testChangesArePersistedWithoutAnExplicitSave() {
        let first = Preferences(defaults: defaults)
        first.duration = .seconds(1800)
        first.options = .screenMaySleep
        first.startSessionOnLaunch = true
        first.customDurationSeconds = 2700

        let second = Preferences(defaults: defaults)
        XCTAssertEqual(second.duration, .seconds(1800))
        XCTAssertEqual(second.options, .screenMaySleep)
        XCTAssertTrue(second.startSessionOnLaunch)
        XCTAssertEqual(second.customDurationSeconds, 2700)
    }

    func testResetRestoresDefaults() {
        let preferences = Preferences(defaults: defaults)
        preferences.duration = .indefinite
        preferences.showDockIcon = true

        preferences.resetToDefaults()

        XCTAssertEqual(preferences.duration, .seconds(8 * 3600))
        XCTAssertFalse(preferences.showDockIcon)
    }
}

final class SessionStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        XCTAssertNil(store.load())

        let session = PersistedSession(
            pid: 4242,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            duration: .seconds(3600),
            options: .standard
        )
        store.save(session)
        XCTAssertEqual(store.load(), session)

        store.save(nil)
        XCTAssertNil(store.load())
    }
}

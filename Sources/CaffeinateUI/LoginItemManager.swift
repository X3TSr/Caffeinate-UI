import CaffeinateKit
import Combine
import Foundation
import ServiceManagement

/// Registers the app as a login item through `SMAppService` (macOS 13+).
///
/// The app must be a real, code signed bundle in a stable location for this to
/// stick — see the troubleshooting section of the README.
@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastError: String?

    /// False when running the raw SwiftPM binary instead of the .app bundle,
    /// where registration cannot work.
    let isSupported: Bool

    init() {
        isSupported = Bundle.main.bundleURL.pathExtension == "app"
        refresh()
    }

    func refresh() {
        guard isSupported else {
            isEnabled = false
            return
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isSupported else {
            lastError = "Launch at login needs the built app bundle."
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            Log.error("Login item update failed: \(error.localizedDescription)")
        }
        refresh()
    }
}

import CaffeinateKit
import Foundation
import UserNotifications

/// Local notifications for session end. Every call is a no-op when the code is
/// not running from a proper .app bundle, because `UNUserNotificationCenter`
/// requires one.
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    private var hasRequestedAuthorization = false

    func requestAuthorization() {
        guard isSupported, !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.warning("Notification authorization failed: \(error.localizedDescription)")
            } else {
                Log.info("Notification authorization granted: \(granted)")
            }
        }
    }

    func postSessionFinished(_ session: CaffeinateController.Session) {
        let body: String
        if let seconds = session.duration.seconds {
            body = "Your \(TimeFormatting.spelledOut(seconds: seconds)) session finished. Your Mac can sleep again."
        } else {
            body = "Your Mac can sleep again."
        }
        post(title: "Caffeinate finished", body: body, identifier: "session-finished")
    }

    func postSessionInterrupted() {
        post(
            title: "Caffeinate stopped",
            body: "The caffeinate process exited unexpectedly. Your Mac can sleep again.",
            identifier: "session-interrupted"
        )
    }

    private func post(title: String, body: String, identifier: String) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifier)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.warning("Could not post notification: \(error.localizedDescription)")
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Show the banner even when the app happens to be frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

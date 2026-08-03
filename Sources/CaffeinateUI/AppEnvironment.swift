import AppKit
import CaffeinateKit
import Combine
import SwiftUI

/// Wires the controller, preferences, login item and notifications together and
/// exposes the handful of actions the views need. Held as a singleton so the
/// `NSApplicationDelegate` and the SwiftUI scenes talk to the same instance.
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let controller: CaffeinateController
    let preferences: Preferences
    let loginItem: LoginItemManager
    private let notifications = NotificationManager.shared
    private var windowObservers: [NSObjectProtocol] = []

    init(
        controller: CaffeinateController = CaffeinateController(),
        preferences: Preferences = Preferences(),
        loginItem: LoginItemManager = LoginItemManager()
    ) {
        self.controller = controller
        self.preferences = preferences
        self.loginItem = loginItem

        controller.onSessionEnded = { [weak self] session, reason in
            self?.handleSessionEnded(session, reason: reason)
        }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching() {
        applyActivationPolicy()
        observeWindows()
        loginItem.refresh()

        if preferences.notifyOnSessionEnd {
            notifications.requestAuthorization()
        }

        // Re-attach to a caffeinate process left running by a crash or a force
        // quit, so it can still be stopped from the UI.
        if let recovered = controller.recoverOrphanedSession() {
            Log.info("Adopted session started at \(recovered.startDate)")
        } else if preferences.startSessionOnLaunch {
            controller.start(options: preferences.options, duration: preferences.duration)
        }

        // SwiftUI opens the `Window` scene on launch. Show it the first time so
        // the app is discoverable, then stay out of the way on later launches.
        Task { @MainActor [weak self] in
            // Give SwiftUI a beat to create its scenes before we touch them.
            try? await Task.sleep(nanoseconds: 150_000_000)
            self?.settleLaunchWindow()
        }
    }

    private func settleLaunchWindow() {
        guard preferences.hasCompletedFirstRun else {
            preferences.hasCompletedFirstRun = true
            openMainWindow()
            return
        }
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.close()
        }
        applyActivationPolicy()
    }

    func applicationWillTerminate() {
        // Never leave the Mac wedged awake after the app is gone.
        controller.stop(reason: .appQuit)
    }

    // MARK: - Actions

    func toggleSession() {
        controller.toggle(options: preferences.options, duration: preferences.duration)
    }

    func startSession() {
        controller.start(options: preferences.options, duration: preferences.duration)
    }

    func stopSession() {
        controller.stop(reason: .stopped)
    }

    /// Selects a duration. When a session is running it is restarted so the new
    /// end time takes effect immediately.
    func selectDuration(_ duration: SessionDuration) {
        preferences.duration = duration
        if controller.isActive {
            controller.changeDuration(to: duration)
        }
    }

    /// Updates the flags, applying them to a running session without changing
    /// when it ends.
    func updateOptions(_ options: CaffeinateOptions) {
        preferences.options = options
        if controller.isActive {
            controller.updateOptions(options)
        }
    }

    func extendSession(by seconds: Int) {
        controller.extend(by: seconds)
    }

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the Settings scene. The selector was renamed in macOS 13, so try
    /// the new name first and fall back to the old one.
    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let selectors = ["showSettingsWindow:", "showPreferencesWindow:"]
        for name in selectors {
            let selector = Selector(name)
            if NSApp.sendAction(selector, to: nil, from: nil) { return }
        }
        Log.warning("Could not open the Settings window")
    }

    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Dock icon

    /// Runs as a menu bar only app unless the user asked for a Dock icon or a
    /// window is on screen.
    func applyActivationPolicy() {
        let hasVisibleWindow = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeMain && !(window is NSPanel)
        }
        let policy: NSApplication.ActivationPolicy =
            (preferences.showDockIcon || hasVisibleWindow) ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }

    private func observeWindows() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.willCloseNotification,
            NSWindow.didBecomeKeyNotification
        ]
        windowObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                // Let AppKit finish updating window state first.
                Task { @MainActor in
                    AppEnvironment.shared.applyActivationPolicy()
                }
            }
        }
    }

    // MARK: - Session end

    private func handleSessionEnded(_ session: CaffeinateController.Session, reason: CaffeinateController.EndReason) {
        guard preferences.notifyOnSessionEnd else { return }
        switch reason {
        case .completed:
            notifications.postSessionFinished(session)
        case .processExited:
            notifications.postSessionInterrupted()
        case .stopped, .appQuit, .restarted:
            break
        }
    }
}

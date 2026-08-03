import AppKit
import CaffeinateKit
import SwiftUI

@main
struct CaffeinateUIApp: App {
    static let mainWindowID = "caffeinate-main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var env = AppEnvironment.shared
    @StateObject private var controller = AppEnvironment.shared.controller
    @StateObject private var preferences = AppEnvironment.shared.preferences
    @StateObject private var loginItem = AppEnvironment.shared.loginItem

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .modifier(SharedEnvironment(
                    env: env,
                    controller: controller,
                    preferences: preferences,
                    loginItem: loginItem
                ))
        } label: {
            // Rebuilt whenever the controller publishes, so the countdown ticks.
            MenuBarLabel(
                isActive: controller.isActive,
                countdown: preferences.showCountdownInMenuBar ? controller.countdownText : nil
            )
        }
        .menuBarExtraStyle(.window)

        Window("Caffeinate UI", id: Self.mainWindowID) {
            MainWindowView()
                .modifier(SharedEnvironment(
                    env: env,
                    controller: controller,
                    preferences: preferences,
                    loginItem: loginItem
                ))
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(controller.isActive ? "Stop Caffeinate" : "Start Caffeinate") {
                    env.toggleSession()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .modifier(SharedEnvironment(
                    env: env,
                    controller: controller,
                    preferences: preferences,
                    loginItem: loginItem
                ))
        }
    }
}

/// Injects the shared objects into a scene's view tree. Each scene needs its
/// own injection, so this keeps it to one line per scene.
private struct SharedEnvironment: ViewModifier {
    let env: AppEnvironment
    let controller: CaffeinateController
    let preferences: Preferences
    let loginItem: LoginItemManager

    func body(content: Content) -> some View {
        content
            .environmentObject(env)
            .environmentObject(controller)
            .environmentObject(preferences)
            .environmentObject(loginItem)
    }
}

/// The menu bar icon, optionally followed by the remaining time.
private struct MenuBarLabel: View {
    let isActive: Bool
    let countdown: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: Theme.symbolName(isActive: isActive))
            if let countdown {
                Text(countdown)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(isActive ? "Caffeinate is running" : "Caffeinate is off")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppEnvironment.shared.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.applicationWillTerminate()
    }

    /// Closing the window leaves the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

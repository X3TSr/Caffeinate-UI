import AppKit
import CaffeinateKit
import SwiftUI

/// The panel that drops down from the menu bar icon. Everything needed for the
/// common case — start, stop, change duration — without opening a window.
struct MenuBarView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var controller: CaffeinateController
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            status
            if controller.isActive {
                ProgressBar(progress: controller.progress, isActive: true)
            }
            primaryButton
            durations
            quickOptions
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: - Sections

    private var status: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: Theme.symbolName(isActive: controller.isActive))
                .font(.system(size: 20))
                .foregroundStyle(controller.isActive ? Theme.accent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.isActive ? "Awake" : "Sleep allowed")
                    .font(.system(size: 13, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if controller.isActive, let countdown = controller.countdownText {
                Text(countdown)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            env.toggleSession()
        } label: {
            Text(controller.isActive ? "Stop" : "Start")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(controller.isActive ? Color.secondary : Theme.accent)
        .keyboardShortcut(.defaultAction)
        .disabled(preferences.options.isEmpty)
    }

    private var durations: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Duration")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if controller.isActive, controller.remainingSeconds != nil {
                    Button("+15m") {
                        env.extendSession(by: 15 * 60)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .help("Push the end time out by 15 minutes")
                }
            }

            DurationPicker(
                selection: preferences.duration,
                customSeconds: preferences.customDurationSeconds,
                columns: 4,
                onSelect: { env.selectDuration($0) }
            )
        }
    }

    private var quickOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keep awake")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ForEach(CaffeinateOptionDescriptor.all.filter { !$0.isAdvanced }) { descriptor in
                Toggle(descriptor.title, isOn: binding(for: descriptor))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help(descriptor.help)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Open Window") {
                openWindow(id: CaffeinateUIApp.mainWindowID)
                env.openMainWindow()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))

            Button("Settings…") {
                env.openSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))

            Spacer()

            Button("Quit") {
                env.quit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .keyboardShortcut("q")
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private var subtitle: String {
        if let error = controller.lastError {
            return error.localizedDescription
        }
        guard controller.isActive else {
            return preferences.options.isEmpty
                ? "No assertions selected"
                : "Ready · \(preferences.duration.label.lowercased())"
        }
        if let end = controller.endDate {
            return "Until \(TimeFormatting.endTime(end))"
        }
        return "No time limit"
    }

    private func binding(for descriptor: CaffeinateOptionDescriptor) -> Binding<Bool> {
        Binding(
            get: { preferences.options[keyPath: descriptor.keyPath] },
            set: { newValue in
                var updated = preferences.options
                updated[keyPath: descriptor.keyPath] = newValue
                env.updateOptions(updated)
            }
        )
    }
}

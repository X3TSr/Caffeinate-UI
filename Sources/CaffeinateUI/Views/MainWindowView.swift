import CaffeinateKit
import SwiftUI

/// The full window: big countdown ring, duration presets and custom entry, all
/// flags, and a live preview of the command being run.
struct MainWindowView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var controller: CaffeinateController
    @EnvironmentObject private var preferences: Preferences

    @State private var customSeconds: Int = 90 * 60

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    ring
                    startStopButton
                    durationSection
                    optionsSection
                    commandSection
                }
                .padding(20)
            }

            footer
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 560, idealHeight: 640)
        .onAppear { customSeconds = preferences.customDurationSeconds }
        .background(.background)
    }

    // MARK: - Ring

    private var ring: some View {
        ProgressRing(progress: controller.progress, isActive: controller.isActive) {
            VStack(spacing: 6) {
                Image(systemName: Theme.symbolName(isActive: controller.isActive))
                    .font(.system(size: 22))
                    .foregroundStyle(controller.isActive ? Theme.accent : .secondary)

                Text(controller.isActive ? "AWAKE" : "ASLEEP OK")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.4)
                    .foregroundStyle(.secondary)

                Text(centerText)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 220, height: 220)
        .padding(.top, 8)
    }

    private var centerText: String {
        guard controller.isActive else { return preferences.duration.shortLabel }
        return controller.countdownText ?? "∞"
    }

    private var subtitle: String {
        if controller.isActive {
            if let end = controller.endDate {
                return "until \(TimeFormatting.endTime(end))"
            }
            return "no time limit"
        }
        return preferences.options.isEmpty ? "nothing selected" : preferences.options.summary.lowercased()
    }

    // MARK: - Controls

    private var startStopButton: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    env.toggleSession()
                } label: {
                    Text(controller.isActive ? "Stop" : "Start")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(controller.isActive ? Color.secondary : Theme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(preferences.options.isEmpty)

                if controller.isActive, controller.remainingSeconds != nil {
                    Button("+15m") {
                        env.extendSession(by: 15 * 60)
                    }
                    .controlSize(.large)
                    .help("Push the end time out by 15 minutes")
                }
            }

            if let error = controller.lastError {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }

            if let session = controller.session, session.isAdopted {
                Label("Recovered a session left running by a previous launch.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var durationSection: some View {
        section("Duration") {
            VStack(alignment: .leading, spacing: 10) {
                DurationPicker(
                    selection: preferences.duration,
                    customSeconds: preferences.customDurationSeconds,
                    showsCustomChip: false,
                    columns: 4,
                    onSelect: { env.selectDuration($0) }
                )

                Divider()

                CustomDurationField(seconds: $customSeconds) { seconds in
                    preferences.customDurationSeconds = seconds
                    env.selectDuration(.custom(seconds: seconds))
                }
            }
        }
    }

    private var optionsSection: some View {
        section("Keep awake") {
            OptionsSection(
                options: preferences.options,
                showAdvanced: $preferences.showAdvancedOptions,
                onChange: { env.updateOptions($0) }
            )
        }
    }

    private var commandSection: some View {
        section("Command") {
            CommandPreview(
                command: CaffeinateCommand.displayString(
                    options: preferences.options,
                    duration: controller.session?.duration ?? preferences.duration
                )
            )
        }
    }

    private var footer: some View {
        HStack {
            if let session = controller.session {
                Text("pid \(session.pid)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Settings…") {
                env.openSettings()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Layout helper

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

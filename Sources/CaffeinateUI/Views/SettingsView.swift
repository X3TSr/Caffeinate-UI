import CaffeinateKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            DefaultsSettingsView()
                .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var loginItem: LoginItemManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch Caffeinate UI at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .disabled(!loginItem.isSupported)

                if !loginItem.isSupported {
                    Text("Available once the app is running from the built bundle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = loginItem.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Start a session as soon as the app launches", isOn: $preferences.startSessionOnLaunch)
                Text("Uses the defaults from the Defaults tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Notify me when a timed session ends", isOn: $preferences.notifyOnSessionEnd)
                Toggle("Show the countdown in the menu bar", isOn: $preferences.showCountdownInMenuBar)
                Toggle("Show an icon in the Dock", isOn: $preferences.showDockIcon)
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.showDockIcon) { _ in
            env.applyActivationPolicy()
        }
        .onChange(of: preferences.notifyOnSessionEnd) { enabled in
            if enabled { NotificationManager.shared.requestAuthorization() }
        }
        .onAppear { loginItem.refresh() }
    }
}

struct DefaultsSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var preferences: Preferences

    @State private var customSeconds: Int = 90 * 60

    var body: some View {
        Form {
            Section("Default duration") {
                DurationPicker(
                    selection: preferences.duration,
                    customSeconds: preferences.customDurationSeconds,
                    showsCustomChip: false,
                    columns: 4,
                    onSelect: { env.selectDuration($0) }
                )

                CustomDurationField(seconds: $customSeconds) { seconds in
                    preferences.customDurationSeconds = seconds
                    env.selectDuration(.custom(seconds: seconds))
                }
            }

            Section("Default assertions") {
                OptionsSection(
                    options: preferences.options,
                    showAdvanced: $preferences.showAdvancedOptions,
                    onChange: { env.updateOptions($0) }
                )
            }

            Section {
                HStack {
                    Text(CaffeinateCommand.displayString(
                        options: preferences.options,
                        duration: preferences.duration
                    ))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Reset") {
                        preferences.resetToDefaults()
                        customSeconds = preferences.customDurationSeconds
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { customSeconds = preferences.customDurationSeconds }
    }
}

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.awakeGradient)

            Text("Caffeinate UI")
                .font(.title2.weight(.semibold))

            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A front end for the built-in macOS `caffeinate` tool. No daemons, no background services — just the same command you would run in Terminal, with a switch on it.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Link("View the project on GitHub", destination: URL(string: "https://github.com/X3TSr/Caffeinate-UI")!)
                .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

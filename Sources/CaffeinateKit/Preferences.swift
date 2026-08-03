import Combine
import Foundation

/// User settings, backed by `UserDefaults`. Every property writes through on
/// change so there is no explicit save step.
public final class Preferences: ObservableObject {
    private enum Key {
        static let options = "defaultOptions"
        static let duration = "defaultDuration"
        static let customSeconds = "customDurationSeconds"
        static let startSessionOnLaunch = "startSessionOnLaunch"
        static let notifyOnSessionEnd = "notifyOnSessionEnd"
        static let showCountdownInMenuBar = "showCountdownInMenuBar"
        static let showDockIcon = "showDockIcon"
        static let showAdvancedOptions = "showAdvancedOptions"
        static let hasCompletedFirstRun = "hasCompletedFirstRun"
    }

    private let defaults: UserDefaults

    /// Flags used when starting from the menu bar or on launch.
    @Published public var options: CaffeinateOptions {
        didSet { write(options, forKey: Key.options) }
    }

    /// Duration used when starting from the menu bar or on launch.
    @Published public var duration: SessionDuration {
        didSet { write(duration, forKey: Key.duration) }
    }

    /// Remembers the last custom duration entered, so the stepper reopens on it.
    @Published public var customDurationSeconds: Int {
        didSet { defaults.set(customDurationSeconds, forKey: Key.customSeconds) }
    }

    /// Begin keeping the Mac awake as soon as the app starts.
    @Published public var startSessionOnLaunch: Bool {
        didSet { defaults.set(startSessionOnLaunch, forKey: Key.startSessionOnLaunch) }
    }

    /// Post a notification when a timed session finishes.
    @Published public var notifyOnSessionEnd: Bool {
        didSet { defaults.set(notifyOnSessionEnd, forKey: Key.notifyOnSessionEnd) }
    }

    /// Show the remaining time next to the menu bar icon.
    @Published public var showCountdownInMenuBar: Bool {
        didSet { defaults.set(showCountdownInMenuBar, forKey: Key.showCountdownInMenuBar) }
    }

    /// Keep an icon in the Dock instead of running as a menu bar only app.
    @Published public var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Key.showDockIcon) }
    }

    /// Reveal the `-m`, `-s` and `-u` toggles.
    @Published public var showAdvancedOptions: Bool {
        didSet { defaults.set(showAdvancedOptions, forKey: Key.showAdvancedOptions) }
    }

    /// Used to open the window once on the very first launch.
    @Published public var hasCompletedFirstRun: Bool {
        didSet { defaults.set(hasCompletedFirstRun, forKey: Key.hasCompletedFirstRun) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        options = Self.read(CaffeinateOptions.self, forKey: Key.options, from: defaults) ?? .standard
        duration = Self.read(SessionDuration.self, forKey: Key.duration, from: defaults)
            ?? .seconds(8 * 60 * 60)
        customDurationSeconds = defaults.object(forKey: Key.customSeconds) as? Int ?? 90 * 60
        startSessionOnLaunch = defaults.bool(forKey: Key.startSessionOnLaunch)
        notifyOnSessionEnd = defaults.object(forKey: Key.notifyOnSessionEnd) as? Bool ?? true
        showCountdownInMenuBar = defaults.object(forKey: Key.showCountdownInMenuBar) as? Bool ?? true
        showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        showAdvancedOptions = defaults.bool(forKey: Key.showAdvancedOptions)
        hasCompletedFirstRun = defaults.bool(forKey: Key.hasCompletedFirstRun)
    }

    /// Restores every setting to its shipped default.
    public func resetToDefaults() {
        options = .standard
        duration = .seconds(8 * 60 * 60)
        customDurationSeconds = 90 * 60
        startSessionOnLaunch = false
        notifyOnSessionEnd = true
        showCountdownInMenuBar = true
        showDockIcon = false
        showAdvancedOptions = false
    }

    // MARK: - Codable storage

    private func write<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func read<Value: Decodable>(
        _ type: Value.Type,
        forKey key: String,
        from defaults: UserDefaults
    ) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

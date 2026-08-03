import Foundation

/// Builds the `/usr/bin/caffeinate` invocation. Kept separate from the
/// controller so the exact command can be previewed in the UI and asserted in
/// tests.
public enum CaffeinateCommand {
    public static let executablePath = "/usr/bin/caffeinate"

    public static var executableURL: URL {
        URL(fileURLWithPath: executablePath)
    }

    /// Arguments only — the executable itself is not included.
    ///
    ///     arguments(options: .standard, duration: .seconds(28800))
    ///     // ["-d", "-i", "-t", "28800"]
    public static func arguments(options: CaffeinateOptions, duration: SessionDuration) -> [String] {
        var args = options.flags
        if let seconds = duration.seconds {
            args.append(contentsOf: ["-t", String(seconds)])
        }
        return args
    }

    /// The full command as you would type it in Terminal. Shown in the UI so
    /// there is never any doubt about what the app is running.
    public static func displayString(options: CaffeinateOptions, duration: SessionDuration) -> String {
        (["caffeinate"] + arguments(options: options, duration: duration)).joined(separator: " ")
    }

    /// True when the system provides `caffeinate`. Should be true on every
    /// supported macOS, but the app degrades gracefully if it is not.
    public static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath)
    }
}

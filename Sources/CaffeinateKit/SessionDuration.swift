import Foundation

/// How long a caffeinate session should last.
public enum SessionDuration: Codable, Equatable, Hashable, Sendable {
    /// Run until stopped — `caffeinate` is launched without `-t`.
    case indefinite
    /// Run for a fixed number of seconds — `caffeinate -t <seconds>`.
    case seconds(Int)

    /// The quick picks offered in the menu bar and the main window.
    public static let presets: [SessionDuration] = [
        .indefinite,
        .seconds(15 * 60),
        .seconds(30 * 60),
        .seconds(60 * 60),
        .seconds(2 * 60 * 60),
        .seconds(4 * 60 * 60),
        .seconds(8 * 60 * 60)
    ]

    /// Bounds for a custom duration: one minute to one day.
    public static let minimumCustomSeconds = 60
    public static let maximumCustomSeconds = 24 * 60 * 60

    /// `nil` for `.indefinite`, otherwise the clamped length in seconds.
    public var seconds: Int? {
        switch self {
        case .indefinite:
            return nil
        case let .seconds(value):
            return max(1, value)
        }
    }

    public var isIndefinite: Bool { seconds == nil }

    /// Builds a duration from seconds, clamping to the supported range.
    public static func custom(seconds: Int) -> SessionDuration {
        .seconds(min(max(seconds, minimumCustomSeconds), maximumCustomSeconds))
    }

    /// Full label, e.g. "8 hours" or "1 hour 30 minutes".
    public var label: String {
        guard let seconds else { return "Indefinite" }
        return TimeFormatting.spelledOut(seconds: seconds)
    }

    /// Compact label for tight spots, e.g. "8h", "90m", "∞".
    public var shortLabel: String {
        guard let seconds else { return "∞" }
        return TimeFormatting.compact(seconds: seconds)
    }

    /// The date a session started at `start` would end.
    public func endDate(from start: Date) -> Date? {
        guard let seconds else { return nil }
        return start.addingTimeInterval(TimeInterval(seconds))
    }
}

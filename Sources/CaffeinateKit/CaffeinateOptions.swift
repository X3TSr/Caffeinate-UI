import Foundation

/// The set of sleep assertions to hand to `/usr/bin/caffeinate`.
///
/// Each property maps to exactly one command line flag, so the struct doubles
/// as the model for the UI toggles and as the source of truth for the command
/// that gets executed.
public struct CaffeinateOptions: Codable, Equatable, Hashable, Sendable {
    /// `-d` — prevent the display from sleeping.
    public var preventDisplaySleep: Bool
    /// `-i` — prevent the system from idle sleeping.
    public var preventIdleSleep: Bool
    /// `-m` — prevent the disk from idle sleeping.
    public var preventDiskIdleSleep: Bool
    /// `-s` — prevent the system from sleeping. Only honoured on AC power.
    public var preventSystemSleepOnAC: Bool
    /// `-u` — declare that the user is active, waking the display if needed.
    public var declareUserActive: Bool

    public init(
        preventDisplaySleep: Bool = true,
        preventIdleSleep: Bool = true,
        preventDiskIdleSleep: Bool = false,
        preventSystemSleepOnAC: Bool = false,
        declareUserActive: Bool = false
    ) {
        self.preventDisplaySleep = preventDisplaySleep
        self.preventIdleSleep = preventIdleSleep
        self.preventDiskIdleSleep = preventDiskIdleSleep
        self.preventSystemSleepOnAC = preventSystemSleepOnAC
        self.declareUserActive = declareUserActive
    }

    /// Keep the screen on and the machine awake. What most people mean by
    /// "don't fall asleep".
    public static let standard = CaffeinateOptions()

    /// Let the display sleep but keep the machine running — for long downloads,
    /// builds, or renders where you want the screen off.
    public static let screenMaySleep = CaffeinateOptions(
        preventDisplaySleep: false,
        preventIdleSleep: true,
        preventDiskIdleSleep: true
    )

    /// The flags in the order they are passed to `caffeinate`.
    public var flags: [String] {
        var result: [String] = []
        if preventDisplaySleep { result.append("-d") }
        if preventIdleSleep { result.append("-i") }
        if preventDiskIdleSleep { result.append("-m") }
        if preventSystemSleepOnAC { result.append("-s") }
        if declareUserActive { result.append("-u") }
        return result
    }

    /// `caffeinate` with no assertions is a no-op, so the UI blocks it.
    public var isEmpty: Bool { flags.isEmpty }

    /// Short human readable description, e.g. "Display, system".
    public var summary: String {
        var parts: [String] = []
        if preventDisplaySleep { parts.append("display") }
        if preventIdleSleep { parts.append("system") }
        if preventDiskIdleSleep { parts.append("disk") }
        if preventSystemSleepOnAC { parts.append("system on AC") }
        if declareUserActive { parts.append("user active") }
        guard let first = parts.first else { return "No assertions" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + parts.dropFirst())
            .joined(separator: ", ")
    }
}

/// Metadata used to render the option toggles, so the UI never hardcodes flag
/// names or help text.
///
/// Not `Sendable`: it carries a `WritableKeyPath`, which is not. These only
/// ever live on the main actor, driving the UI.
public struct CaffeinateOptionDescriptor: Identifiable {
    public let id: String
    public let flag: String
    public let title: String
    public let help: String
    public let isAdvanced: Bool
    public let keyPath: WritableKeyPath<CaffeinateOptions, Bool>

    public static let all: [CaffeinateOptionDescriptor] = [
        .init(
            id: "display",
            flag: "-d",
            title: "Prevent display sleep",
            help: "Keeps the screen on. Turn this off if you only need background work to finish.",
            isAdvanced: false,
            keyPath: \.preventDisplaySleep
        ),
        .init(
            id: "idle",
            flag: "-i",
            title: "Prevent system sleep",
            help: "Stops the Mac from idle sleeping while the session is running.",
            isAdvanced: false,
            keyPath: \.preventIdleSleep
        ),
        .init(
            id: "disk",
            flag: "-m",
            title: "Prevent disk sleep",
            help: "Keeps disks spun up. Useful for long transfers to external drives.",
            isAdvanced: true,
            keyPath: \.preventDiskIdleSleep
        ),
        .init(
            id: "ac",
            flag: "-s",
            title: "Prevent sleep on AC power",
            help: "Stronger than -i, but macOS only honours it while plugged in.",
            isAdvanced: true,
            keyPath: \.preventSystemSleepOnAC
        ),
        .init(
            id: "user",
            flag: "-u",
            title: "Declare user active",
            help: "Wakes the display immediately, as if you had touched the keyboard.",
            isAdvanced: true,
            keyPath: \.declareUserActive
        )
    ]
}

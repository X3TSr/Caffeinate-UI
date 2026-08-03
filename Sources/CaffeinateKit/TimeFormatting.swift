import Foundation

/// Small, dependency free time formatters shared by the menu bar, the window
/// and the notifications.
public enum TimeFormatting {
    /// `"7:42:11"`, or `"42:11"` when under an hour. Used for the countdown.
    public static func clock(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// `"8h"`, `"90m"`, `"45s"`, `"1h 30m"`. Used in menus and buttons.
    public static func compact(seconds: Int) -> String {
        let total = max(0, seconds)
        if total < 60 { return "\(total)s" }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        switch (hours, minutes) {
        case (0, let m):
            return "\(m)m"
        case (let h, 0):
            return "\(h)h"
        case (let h, let m):
            return "\(h)h \(m)m"
        }
    }

    /// `"8 hours"`, `"1 hour 30 minutes"`. Used for labels and notifications.
    public static func spelledOut(seconds: Int) -> String {
        let total = max(0, seconds)
        if total < 60 {
            return "\(total) second\(total == 1 ? "" : "s")"
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    /// `"until 5:30 PM"` style string for the session end time.
    public static func endTime(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDateInToday(date) ? .none : .short
        return formatter.string(from: date)
    }
}

import SwiftUI

/// Colours and metrics shared by the menu bar panel and the window, so the two
/// surfaces stay visually identical.
enum Theme {
    static let awakeStart = Color(red: 1.00, green: 0.75, blue: 0.28)
    static let awakeEnd = Color(red: 0.96, green: 0.44, blue: 0.15)

    static let awakeGradient = LinearGradient(
        colors: [awakeStart, awakeEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let idleGradient = LinearGradient(
        colors: [Color.secondary.opacity(0.45), Color.secondary.opacity(0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = awakeEnd
    static let cornerRadius: CGFloat = 10

    static func gradient(isActive: Bool) -> LinearGradient {
        isActive ? awakeGradient : idleGradient
    }

    /// Symbol shown in the menu bar and next to the status text.
    static func symbolName(isActive: Bool) -> String {
        isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
    }
}

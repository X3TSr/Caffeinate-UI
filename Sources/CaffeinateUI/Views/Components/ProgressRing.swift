import SwiftUI

/// Circular progress used as the centrepiece of the main window.
///
/// `progress` is `nil` for indefinite sessions, which draw a full ring instead
/// of a partial one.
struct ProgressRing<Content: View>: View {
    var progress: Double?
    var isActive: Bool
    var lineWidth: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(
                    Theme.gradient(isActive: isActive),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: trimEnd)
                .opacity(isActive ? 1 : 0.35)

            content()
                .padding(lineWidth * 2)
        }
        .accessibilityElement(children: .combine)
    }

    /// Remaining share of the ring, so it drains clockwise as time passes.
    private var trimEnd: CGFloat {
        guard isActive else { return 0 }
        guard let progress else { return 1 }
        return CGFloat(max(0, min(1, 1 - progress)))
    }
}

/// Slim linear equivalent for the menu bar panel, where a ring is too big.
struct ProgressBar: View {
    var progress: Double?
    var isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(Theme.gradient(isActive: isActive))
                    .frame(width: geometry.size.width * fraction)
                    .animation(.easeInOut(duration: 0.35), value: fraction)
            }
        }
        .frame(height: 6)
    }

    private var fraction: CGFloat {
        guard isActive else { return 0 }
        guard let progress else { return 1 }
        return CGFloat(max(0, min(1, 1 - progress)))
    }
}

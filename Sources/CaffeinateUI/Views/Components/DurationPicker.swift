import CaffeinateKit
import SwiftUI

/// Grid of duration presets plus an optional "Custom" chip.
struct DurationPicker: View {
    var selection: SessionDuration
    var customSeconds: Int
    var showsCustomChip: Bool = true
    var columns: Int = 4
    var onSelect: (SessionDuration) -> Void

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(SessionDuration.presets, id: \.self) { preset in
                DurationChip(
                    title: preset.shortLabel,
                    isSelected: preset == selection,
                    action: { onSelect(preset) }
                )
                .help(preset.label)
            }

            if showsCustomChip {
                DurationChip(
                    title: isCustomSelected ? selection.shortLabel : "Custom",
                    isSelected: isCustomSelected,
                    action: { onSelect(.custom(seconds: customSeconds)) }
                )
                .help("Use the custom duration set in the window")
            }
        }
    }

    private var isCustomSelected: Bool {
        !SessionDuration.presets.contains(selection)
    }
}

struct DurationChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(background)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Theme.awakeGradient
        } else {
            Color.primary.opacity(isHovering ? 0.12 : 0.06)
        }
    }
}

/// Hours and minutes steppers for a custom duration.
struct CustomDurationField: View {
    @Binding var seconds: Int
    var onCommit: (Int) -> Void

    private var hours: Int { seconds / 3600 }
    private var minutes: Int { (seconds % 3600) / 60 }

    var body: some View {
        HStack(spacing: 12) {
            Stepper(value: hoursBinding, in: 0...24) {
                Text("\(hours) h")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .leading)
            }

            Stepper(value: minutesBinding, in: 0...55, step: 5) {
                Text("\(minutes) m")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .leading)
            }

            Spacer(minLength: 0)

            Button("Use") {
                onCommit(clamped(seconds))
            }
            .disabled(seconds < SessionDuration.minimumCustomSeconds)
        }
        .font(.system(size: 12))
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { hours },
            set: { seconds = clamped($0 * 3600 + minutes * 60) }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { minutes },
            set: { seconds = clamped(hours * 3600 + $0 * 60) }
        )
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, 0), SessionDuration.maximumCustomSeconds)
    }
}

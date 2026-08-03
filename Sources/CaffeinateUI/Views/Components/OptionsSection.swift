import AppKit
import CaffeinateKit
import SwiftUI

/// Toggles for the caffeinate flags. Advanced flags are hidden behind a
/// disclosure so the common case stays two checkboxes.
struct OptionsSection: View {
    var options: CaffeinateOptions
    @Binding var showAdvanced: Bool
    var showsFlagNames: Bool = true
    var onChange: (CaffeinateOptions) -> Void

    private var basic: [CaffeinateOptionDescriptor] {
        CaffeinateOptionDescriptor.all.filter { !$0.isAdvanced }
    }

    private var advanced: [CaffeinateOptionDescriptor] {
        CaffeinateOptionDescriptor.all.filter(\.isAdvanced)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(basic) { descriptor in
                optionToggle(descriptor)
            }

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(advanced) { descriptor in
                        optionToggle(descriptor)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Advanced")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if options.isEmpty {
                Label("Pick at least one thing to keep awake.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func optionToggle(_ descriptor: CaffeinateOptionDescriptor) -> some View {
        Toggle(isOn: binding(for: descriptor)) {
            HStack(spacing: 6) {
                Text(descriptor.title)
                    .font(.system(size: 12))
                if showsFlagNames {
                    Text(descriptor.flag)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .toggleStyle(.checkbox)
        .help(descriptor.help)
    }

    private func binding(for descriptor: CaffeinateOptionDescriptor) -> Binding<Bool> {
        Binding(
            get: { options[keyPath: descriptor.keyPath] },
            set: { newValue in
                var updated = options
                updated[keyPath: descriptor.keyPath] = newValue
                onChange(updated)
            }
        )
    }
}

/// Read-only preview of the command being run, with a copy button.
struct CommandPreview: View {
    var command: String

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                copy()
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Copy command")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didCopy = false
        }
    }
}

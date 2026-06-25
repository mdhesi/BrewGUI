import SwiftUI

/// Glass log panel presented while a streamed brew operation runs. Shows live
/// output and a final success/failure state. Read-only; closes via Done.
struct OperationLogView: View {
    @Environment(OperationCenter.self) private var operations
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            header
            logScroll
            footer
        }
        .padding(Spacing.l)
        .frame(minWidth: 540, minHeight: 420)
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            statusIcon
            Text(operations.current?.title ?? "Working…")
                .font(.headline)
            Spacer()
            if operations.isRunning {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder private var statusIcon: some View {
        if let op = operations.current, !op.isRunning {
            Image(systemName: op.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(op.succeeded ? .green : .red)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var logScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(operations.current?.lines ?? []) { line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(line.isError ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(Spacing.s)
            }
            .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .onChange(of: operations.current?.lines.count) {
                if let last = operations.current?.lines.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                operations.dismissLog()
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(operations.isRunning)
            .accessibilityLabel("Close log")
        }
    }
}

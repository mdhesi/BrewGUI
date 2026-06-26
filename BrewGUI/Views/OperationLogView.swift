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
            if operations.trustPrompt != nil {
                trustBanner
            }
            footer
        }
        .padding(Spacing.l)
        .frame(minWidth: 540, minHeight: 420)
    }

    /// Offered when an operation fails because the package is in an untrusted
    /// third-party tap: trusting it and retrying instead of dead-ending.
    @ViewBuilder private var trustBanner: some View {
        if let prompt = operations.trustPrompt {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Untrusted tap")
                        .font(.subheadline.weight(.semibold))
                    Text("This package comes from “\(prompt.tap)”, a third-party tap Homebrew won’t load until you trust it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.s)
                Button {
                    Task { await operations.trustAndRetry() }
                } label: {
                    Label("Trust & Retry", systemImage: "checkmark.shield")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .disabled(operations.isRunning)
                .accessibilityLabel("Trust \(prompt.tap) and retry")
            }
            .padding(Spacing.m)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(.orange.opacity(0.30), lineWidth: 1)
            )
        }
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

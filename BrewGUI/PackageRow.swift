import SwiftUI

struct PackageRow: View {
    let package: InstalledPackage
    var isBusy: Bool = false
    var onRemove: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.isCask ? "app.dashed" : "shippingbox")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .font(.body)
                Text(package.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            // Trailing affordance: busy spinner, or a hover-revealed Remove control.
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if let onRemove, isHovering {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .accessibilityLabel("Remove \(package.name)")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove \(package.name)", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(package.name), \(package.subtitle)")
    }
}

#Preview {
    List {
        PackageRow(package: InstalledPackage(name: "wget", version: "1.21.4", isCask: false), onRemove: {})
        PackageRow(package: InstalledPackage(name: "firefox", version: "120.0", isCask: true), onRemove: {})
        PackageRow(package: InstalledPackage(name: "cmake", version: "3.29.0", isCask: false), isBusy: true)
    }
    .listStyle(.inset)
    .frame(width: 420, height: 220)
}

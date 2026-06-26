import SwiftUI

/// Sidebar destinations, grouped into Discover / Manage / System sections.
enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case browse
    case installed
    case outdated
    case history
    case services
    case cleanup
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .installed: return "Installed"
        case .outdated: return "Outdated"
        case .history: return "History"
        case .services: return "Services"
        case .cleanup: return "Cleanup"
        case .health: return "Health"
        }
    }

    var symbol: String {
        switch self {
        case .browse: return "square.grid.2x2"
        case .installed: return "shippingbox"
        case .outdated: return "arrow.trianglehead.2.clockwise"
        case .history: return "clock.arrow.circlepath"
        case .services: return "bolt.horizontal.circle"
        case .cleanup: return "sparkles"
        case .health: return "stethoscope"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .browse
    @State private var selectedPackage: PackageSummary?
    @State private var operations = OperationCenter()
    @StateObject private var history = RemovalHistoryStore()

    var body: some View {
        Group {
            if BrewProcess.isBrewInstalled {
                mainInterface
            } else {
                OnboardingView()
            }
        }
    }

    private var mainInterface: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
        } detail: {
            packageDetail
        }
        .environment(operations)
        .environmentObject(history)
        .onChange(of: selection) {
            // Switching screens shouldn't leave a stale package in the detail pane.
            selectedPackage = nil
        }
        .sheet(isPresented: $operations.isLogPresented) {
            OperationLogView()
                .environment(operations)
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Discover") {
                row(.browse)
            }
            Section("Manage") {
                row(.installed)
                row(.outdated)
                row(.history)
            }
            Section("System") {
                row(.services)
                row(.cleanup)
                row(.health)
            }
        }
        .navigationTitle("Homebrew")
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private func row(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.symbol)
            .tag(item)
            .accessibilityLabel(item.title)
    }

    /// Middle column: the selected screen.
    @ViewBuilder private var content: some View {
        switch selection ?? .browse {
        case .browse:
            BrowseView(selection: $selectedPackage)
        case .installed:
            InstalledView()
        case .outdated:
            OutdatedView()
        case .history:
            HistoryView()
        case .services:
            PlaceholderScreen(title: "Services", symbol: "bolt.horizontal.circle",
                              message: "Start, stop, and restart Homebrew services.\nComing soon.")
        case .cleanup:
            PlaceholderScreen(title: "Cleanup", symbol: "sparkles",
                              message: "Reclaim disk space with brew cleanup.\nComing soon.")
        case .health:
            PlaceholderScreen(title: "Health", symbol: "stethoscope",
                              message: "Run brew doctor and review your setup.\nComing soon.")
        }
    }

    /// Trailing column: details for the package selected in the content column.
    @ViewBuilder private var packageDetail: some View {
        if let selectedPackage {
            PackageDetailView(package: selectedPackage)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } else {
            PackageDetailPlaceholder()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        }
    }
}

#Preview {
    ContentView()
}

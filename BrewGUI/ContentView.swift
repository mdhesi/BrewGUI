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
        } detail: {
            detail
        }
        .environment(operations)
        .environmentObject(history)
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

    @ViewBuilder private var detail: some View {
        switch selection ?? .browse {
        case .browse:
            BrowseView()
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
}

#Preview {
    ContentView()
}

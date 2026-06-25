import SwiftUI

/// First-launch gate shown when `brew` isn't found on disk. Explains the
/// situation cleanly instead of letting every brew call fail silently.
struct OnboardingView: View {
    private let installURL = URL(string: "https://brew.sh")!

    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "mug.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.s) {
                Text("Homebrew isn’t installed")
                    .font(.title.weight(.semibold))
                Text("BrewGUI couldn’t find the brew command at\n/opt/homebrew or /usr/local. Install Homebrew to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Link(destination: installURL) {
                Label("Get Homebrew", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityLabel("Open the Homebrew installation website")
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Reusable empty/coming-soon screen used by sidebar destinations not yet built.
struct PlaceholderScreen: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .frame(width: 520, height: 400)
}

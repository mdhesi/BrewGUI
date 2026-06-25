import SwiftUI

struct CheckingProgressBar: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.green.opacity(0.15)) // faint track behind the fill
                Capsule()
                    .fill(Color.green)
                    .frame(width: max(0, geo.size.width * progress))
            }
        }
        .frame(height: 10)
        .onAppear {
            progress = 0
            // Fill over 1.8s, then restart — repeats for as long as the bar is on screen.
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

#Preview {
    CheckingProgressBar()
        .padding()
        .frame(width: 300)
}

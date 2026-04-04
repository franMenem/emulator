import SwiftUI

struct GameScreen: View {
    @ObservedObject var renderer: FrameRenderer
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            GameView(renderer: renderer)
                .background(Color.black)

            // Toast overlay
            if let toast = appState.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: appState.toastMessage)
            }
        }
    }
}

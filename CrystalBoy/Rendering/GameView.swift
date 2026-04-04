import Cocoa
import SwiftUI

/// Thread-safe frame buffer that bridges emu thread → SwiftUI.
@MainActor
final class FrameRenderer: ObservableObject {
    @Published var currentFrame: CGImage?

    private let gbWidth = 160
    private let gbHeight = 144
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    nonisolated func updateFrame(pixels: UnsafePointer<UInt32>) {
        let byteCount = 160 * 144 * 4
        let data = Data(bytes: pixels, count: byteCount)

        guard let provider = CGDataProvider(data: data as CFData) else { return }

        let image = CGImage(
            width: 160,
            height: 144,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 160 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        guard let image else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
        }
    }
}

struct GameView: View {
    @ObservedObject var renderer: FrameRenderer

    var body: some View {
        if let cgImage = renderer.currentFrame {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(CGFloat(160) / CGFloat(144), contentMode: .fit)
        } else {
            Color.black
                .aspectRatio(CGFloat(160) / CGFloat(144), contentMode: .fit)
        }
    }
}

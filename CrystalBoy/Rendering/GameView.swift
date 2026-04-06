import Cocoa
import SwiftUI

/// Thread-safe frame buffer that bridges emu thread → SwiftUI.
@MainActor
final class FrameRenderer: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var screenWidth: Int = 160
    @Published var screenHeight: Int = 144

    nonisolated func updateFrame(pixels: UnsafePointer<UInt32>, width: Int, height: Int) {
        let byteCount = width * height * 4
        let data = Data(bytes: pixels, count: byteCount)

        guard let provider = CGDataProvider(data: data as CFData) else { return }

        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
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
            self?.screenWidth = width
            self?.screenHeight = height
        }
    }
}

struct GameView: View {
    @ObservedObject var renderer: FrameRenderer

    private var aspectRatio: CGFloat {
        guard renderer.screenHeight > 0 else { return 10.0 / 9.0 }
        return CGFloat(renderer.screenWidth) / CGFloat(renderer.screenHeight)
    }

    var body: some View {
        if let cgImage = renderer.currentFrame {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            Color.black
                .aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}

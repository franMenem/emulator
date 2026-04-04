import Cocoa
import SwiftUI

final class GameNSView: NSView {
    private var currentFrame: CGImage?
    private let width = 160
    private let height = 144
    private let lock = NSLock()

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.magnificationFilter = .nearest
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func updateFrame(pixels: UnsafePointer<UInt32>) {
        let byteCount = width * height * 4
        let data = Data(bytes: pixels, count: byteCount)

        guard let provider = CGDataProvider(data: data as CFData) else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return }

        lock.lock()
        currentFrame = image
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        lock.lock()
        let frame = currentFrame
        lock.unlock()

        guard let frame, let cgContext = NSGraphicsContext.current?.cgContext else { return }

        cgContext.interpolationQuality = .none // nearest neighbor

        let viewAspect = bounds.width / bounds.height
        let gameAspect = CGFloat(width) / CGFloat(height)

        var drawRect: CGRect
        if viewAspect > gameAspect {
            let drawHeight = bounds.height
            let drawWidth = drawHeight * gameAspect
            drawRect = CGRect(x: (bounds.width - drawWidth) / 2, y: 0, width: drawWidth, height: drawHeight)
        } else {
            let drawWidth = bounds.width
            let drawHeight = drawWidth / gameAspect
            drawRect = CGRect(x: 0, y: (bounds.height - drawHeight) / 2, width: drawWidth, height: drawHeight)
        }

        // Black background
        cgContext.setFillColor(NSColor.black.cgColor)
        cgContext.fill(bounds)

        cgContext.draw(frame, in: drawRect)
    }
}

struct GameView: NSViewRepresentable {
    let gameNSView: GameNSView

    func makeNSView(context: Context) -> GameNSView {
        gameNSView
    }

    func updateNSView(_ nsView: GameNSView, context: Context) {}
}

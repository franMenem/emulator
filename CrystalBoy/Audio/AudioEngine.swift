import AVFoundation
import os

final class AudioEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000
    private let bufferSize = 4096
    private var ringBuffer: [Float] = []
    private var writeIndex = 0
    private var readIndex = 0
    private let lock = OSAllocatedUnfairLock()
    private var _muted = false

    init() {
        ringBuffer = [Float](repeating: 0, count: bufferSize * 2) // stereo
    }

    func start() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)

            self.lock.lock()
            for frame in 0..<frames {
                let available = (self.writeIndex - self.readIndex + self.bufferSize * 2) % (self.bufferSize * 2)
                if available >= 2 {
                    let left = self.ringBuffer[self.readIndex]
                    let right = self.ringBuffer[(self.readIndex + 1) % (self.bufferSize * 2)]
                    self.readIndex = (self.readIndex + 2) % (self.bufferSize * 2)

                    for bufIdx in 0..<ablPointer.count {
                        let buffer = ablPointer[bufIdx]
                        let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                        ptr[frame] = bufIdx == 0 ? left : right
                    }
                } else {
                    // Underrun: output silence
                    for bufIdx in 0..<ablPointer.count {
                        let buffer = ablPointer[bufIdx]
                        let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                        ptr[frame] = 0
                    }
                }
            }
            self.lock.unlock()

            return noErr
        }

        guard let sourceNode else { return }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    func setMuted(_ muted: Bool) {
        lock.lock()
        _muted = muted
        lock.unlock()
    }

    /// Called from emulation thread with each audio sample pair
    func pushSample(left: Int16, right: Int16) {
        lock.lock()
        if !_muted {
            // Check capacity: drop sample if buffer is full
            let capacity = bufferSize * 2
            let used = (writeIndex - readIndex + capacity) % capacity
            if used + 2 < capacity {
                let leftFloat = Float(left) / Float(Int16.max)
                let rightFloat = Float(right) / Float(Int16.max)
                ringBuffer[writeIndex] = leftFloat
                ringBuffer[(writeIndex + 1) % capacity] = rightFloat
                writeIndex = (writeIndex + 2) % capacity
            }
            // else: buffer full, drop this sample (preferable to corruption)
        }
        lock.unlock()
    }

    var currentSampleRate: UInt32 { UInt32(sampleRate) }
}

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
    private var _volume: Float = 1.0
    private let volumeDefaultsKey = "CrystalBoy.Volume"

    init() {
        ringBuffer = [Float](repeating: 0, count: bufferSize * 2)
        _volume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Float ?? 1.0
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
            engine.mainMixerNode.outputVolume = _muted ? 0 : _volume
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    var volume: Float {
        lock.lock()
        let v = _volume
        lock.unlock()
        return v
    }

    var isMuted: Bool {
        lock.lock()
        let m = _muted
        lock.unlock()
        return m
    }

    func setVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        lock.lock()
        _volume = clamped
        lock.unlock()
        engine.mainMixerNode.outputVolume = _muted ? 0 : clamped
        UserDefaults.standard.set(clamped, forKey: volumeDefaultsKey)
    }

    func toggleMute() {
        lock.lock()
        _muted.toggle()
        let muted = _muted
        let vol = _volume
        lock.unlock()
        engine.mainMixerNode.outputVolume = muted ? 0 : vol
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

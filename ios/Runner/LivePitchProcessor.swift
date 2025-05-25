import Foundation
import AVFoundation
import Flutter

class LivePitchProcessor: NSObject {
    private let engine = AVAudioEngine()
    private var samplesBuffer: [Float] = []
    private var sampleRate: Float = 44100
    var resultCallback: (([String: Any]) -> Void)?

    init(resultCallback: @escaping ([String: Any]) -> Void) {
        self.resultCallback = resultCallback
        super.init()
    }

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = engine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)

            guard inputFormat.channelCount > 0 else {
                print("❌ Invalid input format: 0 channels")
                return
            }

            sampleRate = Float(inputFormat.sampleRate)
            samplesBuffer.removeAll()

            inputNode.removeTap(onBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self else { return }

                let channelData = buffer.floatChannelData![0]
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
                self.samplesBuffer.append(contentsOf: samples)
            }

            try engine.start()
            print("🎙️ Mic recording started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        print("🛑 Mic recording stopped")

        guard !samplesBuffer.isEmpty else {
            resultCallback?(["note": "No audio", "frequency": 0.0, "filePath": ""])
            return
        }

        let frequency = detectPitch(from: samplesBuffer, sampleRate: sampleRate)
        let note = PitchDetector.frequencyToNote(frequency)

        var filePath = ""
        if let url = writeWavFile(samples: samplesBuffer, sampleRate: sampleRate) {
            filePath = url.path
            print("🎧 WAV saved to: \(filePath)")
        }

        resultCallback?(["note": note, "frequency": frequency, "filePath": filePath])
        samplesBuffer.removeAll()
    }

    private func detectPitch(from samples: [Float], sampleRate: Float) -> Float {
        let frameSize = 2048
        let hopSize = 1024
        var pitches: [Float] = []

        for i in 0..<10 {
            let start = i * hopSize
            let end = start + frameSize
            guard end < samples.count else { break }

            let frame = Array(samples[start..<end])
            if rms(frame) < 0.005 { continue }

            let window = hannWindow(count: frame.count)
            let windowed = zip(frame, window).map(*)

            if let pitch = autocorrelation(from: windowed, sampleRate: sampleRate), pitch < 1000 {
                pitches.append(pitch)
            }
        }

        guard !pitches.isEmpty else { return 0.0 }
        return pitches.reduce(0, +) / Float(pitches.count)
    }

    private func rms(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }

    private func autocorrelation(from samples: [Float], sampleRate: Float) -> Float? {
        let n = samples.count
        var autocorr = [Float](repeating: 0.0, count: n)

        for lag in 0..<n {
            for i in 0..<(n - lag) {
                autocorr[lag] += samples[i] * samples[i + lag]
            }
        }

        let minLag = Int(sampleRate / 500)
        let maxLag = Int(sampleRate / 50)
        guard maxLag < autocorr.count else { return nil }

        var bestLag = -1
        var bestValue: Float = 0.0
        for lag in minLag..<maxLag {
            if autocorr[lag] > bestValue {
                bestValue = autocorr[lag]
                bestLag = lag
            }
        }

        guard bestLag > 0 else { return nil }
        return sampleRate / Float(bestLag)
    }

    private func hannWindow(count: Int) -> [Float] {
        guard count > 0 else { return [] }
        let factor = 2.0 * Float.pi / Float(count - 1)
        return (0..<count).map { 0.5 * (1 - cos(factor * Float($0))) }
    }

    private func writeWavFile(samples: [Float], sampleRate: Float) -> URL? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("recorded_audio.wav")

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        do {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buffer.frameLength = buffer.frameCapacity
            let channel = buffer.floatChannelData![0]
            for i in 0..<samples.count {
                channel[i] = samples[i]
            }

            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try audioFile.write(from: buffer)

            return fileURL
        } catch {
            print("❌ Failed to write WAV file: \(error)")
            return nil
        }
    }
}

import Foundation
import AVFoundation
import Accelerate

class PitchDetector {
    private let frameSize = 2048
    private let hopSize = 4096               // fewer overlapping frames
    private let silenceThreshold: Float = 0.01
    private let maxFramesToProcess = 30
    private let maxDuration: Float = 15.0    // seconds
    private let minFrequency: Float = 80.0
    private let maxFrequency: Float = 1500.0

    func analyze(samples: [Float], sampleRate: Float, progressSink: FlutterEventSink?) -> Float {
            let maxSamples = Int(sampleRate * maxDuration)
            let trimmed = samples.prefix(maxSamples)
            let totalFrames = (trimmed.count - frameSize) / hopSize

            var pitches: [Float] = []
            print("🔍 Optimized analysis: \(totalFrames) frames max, 15s audio")

            for i in 0..<totalFrames {
                let start = i * hopSize
                let frame = trimmed[start..<start + frameSize]
                let rms = sqrt(frame.reduce(0) { $0 + $1 * $1 } / Float(frameSize))
                if rms < silenceThreshold { continue }

                if let f = detectYINPitch(samples: Array(frame), sampleRate: sampleRate),
                   f >= minFrequency, f <= maxFrequency {
                    pitches.append(f)
                    let progress = 40 + Int(Float(i) / Float(maxFramesToProcess) * 30)
                    DispatchQueue.main.async {
                        progressSink?(min(progress, 95))
                    }
                    if pitches.count >= maxFramesToProcess { break }
                }
            }

            guard !pitches.isEmpty else {
                print("⚠️ No valid pitches found.")
                return 0.0
            }

            let avg = pitches.reduce(0, +) / Float(pitches.count)
            print("✅ Average pitch over \(pitches.count) frames: \(avg) Hz")
            return avg
        }

    private func detectYINPitch(samples: [Float], sampleRate: Float) -> Float? {
        let N = samples.count
        var diff = [Float](repeating: 0, count: N / 2)
        var cmndf = [Float](repeating: 0, count: N / 2)

        for tau in 1..<N / 2 {
            var sum: Float = 0
            for i in 0..<N - tau {
                let delta = samples[i] - samples[i + tau]
                sum += delta * delta
            }
            diff[tau] = sum
        }

        cmndf[0] = 1
        var runningSum: Float = 0
        for tau in 1..<N / 2 {
            runningSum += diff[tau]
            cmndf[tau] = diff[tau] / ((runningSum / Float(tau)) + 1e-6)
        }

        let threshold: Float = 0.15
        for tau in 1..<N / 2 {
            if cmndf[tau] < threshold {
                return sampleRate / parabolicInterpolation(cmndf: cmndf, tau: tau)
            }
        }
        return nil
    }

    private func parabolicInterpolation(cmndf: [Float], tau: Int) -> Float {
        guard tau > 0, tau < cmndf.count - 1 else { return Float(tau) }
        let x0 = cmndf[tau - 1], x1 = cmndf[tau], x2 = cmndf[tau + 1]
        let denom = 2 * (2 * x1 - x2 - x0)
        guard abs(denom) > 1e-6 else { return Float(tau) }
        return Float(tau) + (x2 - x0) / denom
    }

    static func frequencyToNote(_ freq: Float) -> String {
        guard freq > 0 else { return "Too Low" }
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let midi = 69 + 12 * log2(freq / 440.0)
        return notes[(Int(round(midi)) + 12) % 12]
    }
    
    func detectPitch(from path: String, progressSink: FlutterEventSink?, completion: @escaping (_ note: String, _ frequency: Float) -> Void, onError: @escaping (_ error: String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
                do {
                    DispatchQueue.main.async {
                                    progressSink?(0) // Start from 0%
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    progressSink?(10)
                                }
                    let url = URL(fileURLWithPath: path)
                    let audioFile = try AVAudioFile(forReading: url)
                    let format = audioFile.processingFormat
                    let frameCount = AVAudioFrameCount(audioFile.length)
                    
                    DispatchQueue.main.async { progressSink?(20) } // 0%: File opened

                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
                    try audioFile.read(into: buffer)
                    
                    DispatchQueue.main.async { progressSink?(30) } // 30%: Audio read

                    let channelCount = Int(format.channelCount)
                    let sampleCount = Int(buffer.frameLength)

                    var monoSamples = [Float](repeating: 0.0, count: sampleCount)
                    for c in 0..<channelCount {
                        let channel = buffer.floatChannelData![c]
                        for i in 0..<sampleCount {
                            monoSamples[i] += channel[i]
                        }
                    }
                    for i in 0..<sampleCount {
                        monoSamples[i] /= Float(channelCount)
                    }

                    DispatchQueue.main.async { progressSink?(40) } // 50%: Mono conversion

                    let detector = PitchDetector()
                    let frequency = self.analyze(samples: monoSamples, sampleRate: Float(format.sampleRate), progressSink: progressSink)

                    DispatchQueue.main.async { progressSink?(95) } // 95%: Analysis done

                    let note = PitchDetector.frequencyToNote(frequency)

                    DispatchQueue.main.async {
                        progressSink?(95) // 100%: Complete
                        completion(note, frequency)
                        progressSink?(100)
                    }

                } catch {
                    print("❌ Error reading audio file: \(error)")
                    DispatchQueue.main.async {
                        progressSink?(100)
                        completion("Error", 0.0)
                    }
                }
            }
    }

}

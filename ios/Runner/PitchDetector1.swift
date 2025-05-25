import Foundation
import Accelerate

class PitchDetector1 {

    /// Analyze pitch from raw audio samples
    func analyze(samples: [Float], sampleRate: Float) -> Float {
        let frameSize = 2048
        let hopSize = 1024
        let skipSamples = Int(sampleRate * 2) // skip first 2 seconds

        guard samples.count > skipSamples + frameSize else {
            return 0.0
        }

        let trimmed = Array(samples.dropFirst(skipSamples))
        var pitches: [Float] = []

        for i in 0..<5 {
            let start = i * hopSize
            let end = start + frameSize
            if end > trimmed.count { break }

            let frame = Array(trimmed[start..<end])
            if rms(frame) < 0.001 { continue }

            if let pitch = detectPitchAutocorrelation(from: frame, sampleRate: sampleRate) {
                pitches.append(pitch)
            }
        }

        guard !pitches.isEmpty else {
            return 0.0
        }

        return pitches.reduce(0, +) / Float(pitches.count)
    }

    /// RMS for silence detection
    private func rms(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }

    /// Autocorrelation-based pitch detection
    func detectPitchAutocorrelation(from samples: [Float], sampleRate: Float) -> Float? {
        let n = samples.count

        var window = [Float](repeating: 0.0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0.0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        var autocorr = [Float](repeating: 0.0, count: n)
        for lag in 0..<n {
            for i in 0..<(n - lag) {
                autocorr[lag] += windowed[i] * windowed[i + lag]
            }
        }

        let minLag = Int(sampleRate / 500)
        let maxLag = Int(sampleRate / 50)
        if maxLag >= autocorr.count { return nil }

        var bestLag = -1
        var bestValue: Float = 0.0
        for lag in minLag..<maxLag {
            if autocorr[lag] > bestValue {
                bestValue = autocorr[lag]
                bestLag = lag
            }
        }

        guard bestLag > 0 else {
            return nil
        }

        return sampleRate / Float(bestLag)
    }

    /// Map frequency to musical note
    static func frequencyToNote(_ freq: Float) -> String {
        guard freq > 20 else { return "Too low" }

        let noteFrequencies: [String: Double] = [
            "C": 261.63, "C#": 277.18, "D": 293.66, "D#": 311.13, "E": 329.63,
            "F": 349.23, "F#": 369.99, "G": 392.00, "G#": 415.30, "A": 440.00,
            "A#": 466.16, "B": 493.88
        ]

        let closest = noteFrequencies.min {
            abs($0.value - Double(freq)) < abs($1.value - Double(freq))
        }

        return closest?.key ?? "Unknown"
    }
}

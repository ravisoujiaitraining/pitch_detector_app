import Foundation
import AVFoundation
import AudioKit
import SoundpipeAudioKit
import AudioKitEX

@objc class AudioKitPitchShifter: NSObject {

    @objc static func shiftPitch(inputPath: String,
                                 outputPath: String,
                                 semitoneShift: Float,
                                 completion: @escaping (Bool, String?) -> Void) {

        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        let engine = AudioEngine()
        let player = AudioPlayer()

        do {
            try player.load(url: inputURL)
        } catch {
            completion(false, "❌ Failed to load file: \(error.localizedDescription)")
            return
        }

        // 🎚 Pitch shifting only
        let pitchShifter = TimePitch(player)
        pitchShifter.pitch = semitoneShift * 100
        pitchShifter.rate = 1.0  // ✅ preserve tempo

        engine.output = pitchShifter

        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
            completion(false, "❌ Failed to create AVAudioFormat")
            return
        }

        do {
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)

            try engine.start()
            print("🚀 Rendering offline with pitch only")

            try engine.renderToFile(outputFile, duration: player.duration, prerender: {
                player.play()
            })

            engine.stop()
            print("✅ Render complete \(outputURL.path)")
            completion(true, nil)

        } catch {
            completion(false, "❌ Rendering error: \(error.localizedDescription)")
        }
    }
}

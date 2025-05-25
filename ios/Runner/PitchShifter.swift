import Foundation
import AVFoundation

@objc class PitchShifter: NSObject {

    @objc static func shiftPitch(inputPath: String, outputPath: String, semitoneShift: Float, completion: @escaping (Bool, String?) -> Void) {

        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        pitch.pitch = semitoneShift * 100
        pitch.rate = 1.0  // ✅ Keeps tempo

        engine.attach(player)
        engine.attach(pitch)

        var audioFile: AVAudioFile
        var outputFile: AVAudioFile
        let bufferSize: AVAudioFrameCount = 4096

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            audioFile = try AVAudioFile(forReading: inputURL)
            let inputFormat = audioFile.processingFormat  // ✅ Use source format

            outputFile = try AVAudioFile(forWriting: outputURL, settings: inputFormat.settings)

            engine.connect(player, to: pitch, format: inputFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: inputFormat)

            engine.mainMixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, _ in
                do {
                    try outputFile.write(from: buffer)
                } catch {
                    print("❌ Buffer write error: \(error)")
                    completion(false, error.localizedDescription)
                }
            }

        } catch {
            completion(false, "❌ Setup error: \(error.localizedDescription)")
            return
        }

        engine.prepare()

        do {
            try engine.start()
            print("✅ AVAudioEngine started")

            player.scheduleFile(audioFile, at: nil, completionHandler: {
                DispatchQueue.main.async {
                    if engine.isRunning {
                        player.stop()
                        engine.stop()
                    }
                    engine.mainMixerNode.removeTap(onBus: 0)
                    print("✅ Pitch shifting complete")
                    completion(true, nil)
                }
            })

            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.0) {
                if engine.isRunning {
                    player.stop()
                    engine.stop()
                    engine.mainMixerNode.removeTap(onBus: 0)
                    print("⏱ Fallback cleanup")
                    completion(true, nil)
                }
            }

            player.play()
            print("▶️ Playback started for pitch shifting")

        } catch {
            completion(false, "❌ Engine start error: \(error.localizedDescription)")
        }
    }
}

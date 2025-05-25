import UIKit
import Flutter
import AVFoundation
@main
@objc class AppDelegate: FlutterAppDelegate {
    private let methodChannelName = "com.example.pitch_detector"
    private var bufferedMicProcessor: LivePitchProcessor?
    private var stopResultCallback: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            
            switch call.method {
                
            case "detectPitch":
                if let args = call.arguments as? [String: Any],
                   let filePath = args["filePath"] as? String {
                    self.detectPitch(from: filePath) { note, frequency in
                        result(["note": note, "frequency": frequency])
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing filePath", details: nil))
                }
                
            case "shiftPitchAudioKit":
                if let args = call.arguments as? [String: Any],
                   let input = args["input"] as? String,
                   let output = args["output"] as? String,
                   let semitones = args["semitones"] as? Double {
                    
                    print("🎚 Shifting pitch by \(semitones) semitones")
                    
                    AudioKitPitchShifter.shiftPitch(
                        inputPath: input,
                        outputPath: output,
                        semitoneShift: Float(semitones),
                        completion: { success, error in
                            if success {
                                result(["success": true, "outputPath": output])
                            } else {
                                result(FlutterError(code: "PITCH_SHIFT_FAILED", message: error ?? "Unknown error", details: nil))
                            }
                        }
                    )
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing inputs for pitch shift", details: nil))
                }
                
            case "shiftPitchVideo":
                print("✅ In to the shiftPitchVideo")
               /* if let args = call.arguments as? [String: Any],
                   let input = args["input"] as? String,
                   let output = args["output"] as? String,
                   let semitones = args["semitones"] as? Double {
                    self.handleMP4PitchShift(inputPath: input, outputPath: output, semitones: semitones, result: result)
                }*/
                
                guard let args = call.arguments as? [String: Any],
            let videoPath = args["input"] as? String,
            let semitones = args["semitones"] as? Double else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected videoPath and semitones", details: nil))
                                    return
                                }

        self.processAndMergePitch(for: videoPath, semitoneShift: Float(semitones)) { success in
            if success {
                let finalPath = FileManager.default.temporaryDirectory
                                            .appendingPathComponent("video_with_shifted_audio.mp4").path
                                        result(["success": true, "outputPath": finalPath])
                                    } else {
                                        result(FlutterError(code: "PITCH_SHIFT_FAILED", message: "Could not process and merge", details: nil))
                                    }
                                }
                
            case "startListening":
                self.bufferedMicProcessor = LivePitchProcessor(resultCallback: { _ in })
                self.bufferedMicProcessor?.start()
                result(nil)
                
            case "stopListening":
                if let processor = self.bufferedMicProcessor {
                    self.stopResultCallback = result
                    processor.resultCallback = { data in
                        self.stopResultCallback?(data)
                        self.stopResultCallback = nil
                    }
                    processor.stop()
                    self.bufferedMicProcessor = nil
                } else {
                    result(FlutterError(code: "NO_ACTIVE_LISTENER", message: "No mic recording in progress", details: nil))
                }
            case "shiftVideoPitchOnly":
                guard let args = call.arguments as? [String: Any],
                      let videoPath = args["input"] as? String,
                      let outputPath = args["output"] as? String,
                      let semitones = args["semitones"] as? Double else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing inputs", details: nil))
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory
                let extractedAudioURL = tempDir.appendingPathComponent("extracted_from_video.m4a")

                self.extractAudioFromVideo(videoURL: URL(fileURLWithPath: videoPath), outputAudioURL: extractedAudioURL) { success in
                    guard success else {
                        result(FlutterError(code: "EXTRACTION_FAILED", message: "Audio extraction failed", details: nil))
                        return
                    }

                    AudioKitPitchShifter.shiftPitch(
                        inputPath: extractedAudioURL.path,
                        outputPath: outputPath,
                        semitoneShift: Float(semitones)
                    ) { shiftSuccess, error in
                        if shiftSuccess {
                            result(["success": true, "outputPath": outputPath])
                        } else {
                            result(FlutterError(code: "PITCH_SHIFT_FAILED", message: error ?? "Unknown error", details: nil))
                        }
                    }
                }
            case "mergeShiftedAudioWithVideo":
                guard let args = call.arguments as? [String: Any],
                      let videoPath = args["videoPath"] as? String,
                      let audioPath = args["audioPath"] as? String,
                      let outputPath = args["outputPath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing merge parameters", details: nil))
                    return
                }

                self.mergeAudioWithVideo(
                    videoURL: URL(fileURLWithPath: videoPath),
                    audioURL: URL(fileURLWithPath: audioPath),
                    outputURL: URL(fileURLWithPath: outputPath)
                ) { success in
                    if success {
                        result(["success": true, "outputPath": outputPath])
                    } else {
                        result(FlutterError(code: "MERGE_FAILED", message: "Failed to merge audio and video", details: nil))
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func detectPitch(from filePath: String, completion: @escaping (String, Float) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = URL(fileURLWithPath: filePath)
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
                
                try audioFile.read(into: buffer)
                
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
                
                print("🔍 Running pitch detector in background thread...")
                let detector = PitchDetector()
                let frequency = detector.analyze(samples: monoSamples, sampleRate: Float(format.sampleRate))
                let note = PitchDetector.frequencyToNote(frequency)
                
                DispatchQueue.main.async {
                    completion(note, frequency)
                }
                
            } catch {
                print("❌ Error reading audio file: \(error)")
                DispatchQueue.main.async {
                    completion("Error", 0.0)
                }
            }
        }
    }
    
    // MARK: - MP4 pitch shift logic
    
    private func handleMP4PitchShift(inputPath: String, outputPath: String, semitones: Double, result: @escaping FlutterResult) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        let asset = AVAsset(url: inputURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            result(FlutterError(code: "NO_VIDEO", message: "Video track not found", details: nil))
            return
        }
        
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            result(FlutterError(code: "COMPOSITION_ERROR", message: "Failed to create video track", details: nil))
            return
        }
        
        try? compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        
        let audioExportPath = FileManager.default.temporaryDirectory.appendingPathComponent("extracted_audio.m4a")
        exportAudio(from: asset, to: audioExportPath) { exportSuccess in
            guard exportSuccess else {
                result(FlutterError(code: "EXPORT_FAILED", message: "Audio extraction failed", details: nil))
                return
            }
            
            let shiftedAudioPath = FileManager.default.temporaryDirectory.appendingPathComponent("shifted_audio.m4a")
            
            AudioKitPitchShifter.shiftPitch(
                inputPath: audioExportPath.path,
                outputPath: shiftedAudioPath.path,
                semitoneShift: Float(semitones)
            ) { success, error in
                if !success {
                    result(FlutterError(code: "SHIFT_FAILED", message: error ?? "Unknown error", details: nil))
                    return
                }
                let tempDir = FileManager.default.temporaryDirectory
let shiftedM4AURL = tempDir.appendingPathComponent("shifted_audio.m4a")
                self.convertWavToM4A(inputPath: shiftedAudioPath.path, outputPath: shiftedM4AURL.path) { convertSuccess, convertError in
                    guard convertSuccess else {
                        print("❌ WAV to M4A conversion failed: \(convertError ?? "Unknown error")")
                       // completion(false)
                        return
                    }
                }
            print("✅ Converted to M4A: \(shiftedM4AURL.lastPathComponent)")

                self.mergeAudioWithVideo(
                    videoComposition: composition,
                    audioURL: shiftedM4AURL,
                    outputURL: outputURL
                ) { mergeSuccess in
                    if mergeSuccess {
                        result(["success": true, "outputPath": outputPath])
                    } else {
                        result(FlutterError(code: "MERGE_FAILED", message: "Failed to merge audio and video", details: nil))
                    }
                }
            }
        }
    }
    
    private func exportAudio(from asset: AVAsset, to outputURL: URL, completion: @escaping (Bool) -> Void) {
        // Check for audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            print("❌ No audio track found in video.")
            completion(false)
            return
        }
        
        print("🎧 Found audio track: \(audioTrack.formatDescriptions)")
        
        // Print export presets
        print("📦 Supported presets: \(AVAssetExportSession.exportPresets(compatibleWith: asset))")
        
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("❌ Failed to create AVAssetExportSession.")
            completion(false)
            return
        }
        
        // Ensure the output file doesn't already exist
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            print("⚠️ Output file already exists. Deleting it.")
            try? fileManager.removeItem(at: outputURL)
        }
        
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                print("✅ Audio extracted successfully to: \(outputURL.path)")
                completion(true)
                
            case .failed:
                print("❌ Audio export failed with error: \(exporter.error?.localizedDescription ?? "Unknown error")")
                completion(false)
                
            case .cancelled:
                print("⚠️ Audio export was cancelled.")
                completion(false)
                
            default:
                print("⚠️ Audio export finished with unexpected status: \(exporter.status.rawValue)")
                completion(false)
            }
        }
    }
    
    
    
    private func mergeAudioWithVideo(videoComposition: AVMutableComposition, audioURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        let audioAsset = AVAsset(url: audioURL)
        
        // Ensure tracks are loaded
        audioAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            var error: NSError?
            let status = audioAsset.statusOfValue(forKey: "tracks", error: &error)
            
            if status != .loaded {
                print("❌ Failed to load audio tracks: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let audioTracks = audioAsset.tracks(withMediaType: .audio)
            print("📦 Total tracks in audio asset: \(audioAsset.tracks.count)")
            print("🎧 Audio tracks found: \(audioTracks.count)")
            print("⏱ Audio duration: \(audioAsset.duration.seconds) sec")
            
            guard let audioTrack = audioTracks.first,
                  let compAudioTrack = videoComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("❌ No audio track found or failed to create composition audio track")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                try compAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoComposition.duration),
                    of: audioTrack,
                    at: .zero
                )
            } catch {
                print("❌ Error inserting audio track: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Remove existing output if present
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputURL.path) {
                try? fileManager.removeItem(at: outputURL)
            }
            
            guard let exporter = AVAssetExportSession(asset: videoComposition, presetName: AVAssetExportPresetHighestQuality) else {
                print("❌ Failed to create export session")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true
            
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    print("✅ Merged audio and video successfully to: \(outputURL.path)")
                    DispatchQueue.main.async { completion(true) }
                case .failed:
                    print("❌ Export failed: \(exporter.error?.localizedDescription ?? "Unknown error")")
                    DispatchQueue.main.async { completion(false) }
                case .cancelled:
                    print("⚠️ Export cancelled")
                    DispatchQueue.main.async { completion(false) }
                default:
                    print("⚠️ Export finished with unexpected status: \(exporter.status.rawValue)")
                    DispatchQueue.main.async { completion(false) }
                }
            }
        }
    }
    func convertWavToM4A(inputPath: String, outputPath: String, completion: @escaping (Bool, String?) -> Void) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

       // let asset = AVAsset(url: inputURL)
        print("🧪 Attempting to load: \(inputURL.path)")
        let testAsset = AVAsset(url: inputURL)
        print("📦 Track count: \(testAsset.tracks.count)")
        print("🎧 Audio tracks: \(testAsset.tracks(withMediaType: .audio).count)")
        print("⏱ Duration: \(testAsset.duration.seconds)")
        guard let exportSession = AVAssetExportSession(asset: testAsset, presetName: AVAssetExportPresetAppleM4A) else {
            print("❌ Failed to create export session")
            completion(false, "Cannot create export session")
            return
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("✅ WAV to M4A conversion complete: \(outputURL.path)")
                completion(true, nil)
            case .failed:
                print("❌ Conversion failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                completion(false, exportSession.error?.localizedDescription)
            case .cancelled:
                print("⚠️ Conversion cancelled")
                completion(false, "Cancelled")
            default:
                print("⚠️ Unexpected conversion status: \(exportSession.status.rawValue)")
                completion(false, "Unexpected status")
            }
        }
    }
    // MARK: - Merge Audio + Video
        func mergeAudioWithVideo(videoURL: URL, audioURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
            let videoAsset = AVAsset(url: videoURL)
            let audioAsset = AVAsset(url: audioURL)

            let composition = AVMutableComposition()

            guard
                let videoTrack = videoAsset.tracks(withMediaType: .video).first,
                let compVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid)
            else {
                completion(false)
                return
            }

            do {
                try compVideoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoAsset.duration),
                    of: videoTrack,
                    at: .zero
                )
            } catch {
                print("❌ Video insert failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            audioAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                var error: NSError?
                let status = audioAsset.statusOfValue(forKey: "tracks", error: &error)

                guard status == .loaded,
                      let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
                      let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                else {
                    print("❌ Could not load audio track")
                    completion(false)
                    return
                }

                do {
                    try compAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: videoAsset.duration),
                        of: audioTrack,
                        at: .zero
                    )
                } catch {
                    print("❌ Audio insert failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try? FileManager.default.removeItem(at: outputURL)
                }

                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    completion(false)
                    return
                }

                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        print("✅ Merged video created at: \(outputURL.path)")
                        completion(true)
                    } else {
                        print("❌ Export failed: \(exportSession.error?.localizedDescription ?? "Unknown")")
                        completion(false)
                    }
                }
            }
        }
    // MARK: - Helper: Orchestrates full flow
        func processAndMergePitch(for videoPath: String, semitoneShift: Float, completion: @escaping (Bool) -> Void) {
            let videoURL = URL(fileURLWithPath: videoPath)
            let tempDir = FileManager.default.temporaryDirectory

            let extractedAudioURL = tempDir.appendingPathComponent("extracted_audio.m4a")
            let shiftedWavURL = tempDir.appendingPathComponent("shifted_audio.wav")
            let shiftedM4AURL = tempDir.appendingPathComponent("shifted_audio.m4a")
            let outputVideoURL = tempDir.appendingPathComponent("video_with_shifted_audio.mp4")

            extractAudioFromVideo(videoURL: videoURL, outputAudioURL: extractedAudioURL) { success in
                guard success else {
                    completion(false)
                    return
                }

                AudioKitPitchShifter.shiftPitch(
                    inputPath: extractedAudioURL.path,
                    outputPath: shiftedWavURL.path,
                    semitoneShift: semitoneShift
                ) { shiftSuccess, error in
                    guard shiftSuccess else {
                        print("❌ Pitch shift failed: \(error ?? "Unknown error")")
                        completion(false)
                        return
                    }
                    
                    self.convertWavToM4A(inputPath: shiftedWavURL.path, outputPath: shiftedM4AURL.path) { convertSuccess, convertError in
                        guard convertSuccess else {
                            print("❌ WAV to M4A conversion failed: \(convertError ?? "Unknown error")")
                            completion(false)
                            return
                        }
                    }
                    self.mergeAudioWithVideo(videoURL: videoURL, audioURL: shiftedM4AURL, outputURL: outputVideoURL) { mergeSuccess in
                        completion(mergeSuccess)
                    }
                }
            }
        }

    // MARK: - Extract Audio
        func extractAudioFromVideo(videoURL: URL, outputAudioURL: URL, completion: @escaping (Bool) -> Void) {
            let asset = AVAsset(url: videoURL)

            guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                print("❌ No audio track in video")
                completion(false)
                return
            }

            let composition = AVMutableComposition()
            guard let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                completion(false)
                return
            }

            do {
                try compAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: asset.duration),
                    of: audioTrack,
                    at: .zero
                )
            } catch {
                print("❌ Failed to insert audio track: \(error.localizedDescription)")
                completion(false)
                return
            }

            if FileManager.default.fileExists(atPath: outputAudioURL.path) {
                try? FileManager.default.removeItem(at: outputAudioURL)
            }

            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
                completion(false)
                return
            }

            exporter.outputURL = outputAudioURL
            exporter.outputFileType = .m4a

            exporter.exportAsynchronously {
                if exporter.status == .completed {
                    print("✅ Audio extracted to: \(outputAudioURL.path)")
                    completion(true)
                } else {
                    print("❌ Audio extraction failed: \(exporter.error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                }
            }
        }
}

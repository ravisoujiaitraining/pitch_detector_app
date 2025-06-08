package com.example.pitch_detector_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.pitch_detector"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
print("Configuring Flutter Engine for Pitch Detector")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "detectPitch") {
                print("Received method call to detectPitch with parameters: ${call.arguments}")
                val path = call.argument<String>("filePath")
                if (path != null) {
                    PitchDetector.detectPitch(path, result)
                } else {
                    result.error("INVALID_PATH_Android", "Path was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

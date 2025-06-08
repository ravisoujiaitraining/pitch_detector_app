import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AndroidPitchService {
  static const MethodChannel _channel = MethodChannel('com.example.pitch');

  static Future<double?> detectPitch(String filePath) async {
    try {
      final pitch = await _channel.invokeMethod('detectPitch', {'filePath': filePath});
      return pitch is double ? pitch : null;
    } catch (e) {
      debugPrint("Android pitch detection failed: $e");
      return null;
    }
  }
}

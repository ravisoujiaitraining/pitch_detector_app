import 'dart:io';

import 'package:flutter/services.dart';
class PitchProcessingService {
  static const MethodChannel _channel = MethodChannel('com.example.pitch_detector');

  /// Detects pitch from a given audio or video file path
  static Future<Map<String, dynamic>?> detectPitch(String filePath) async {
    try {

      if (Platform.isAndroid) {
          print("Android pitch detection ........");

      try {
        final result = await _channel.invokeMethod('detectPitch', {'filePath': filePath});
        return {
        'note': result?['note'],
        'frequency': result?['frequency']
      };
      } catch (e) {
        print("Android pitch detection failed: $e");
        return null;
      }
    } else {
      final result = await _channel.invokeMethod<Map>('detectPitch', {'filePath': filePath});
      return {
        'note': result?['note'],
        'frequency': result?['frequency']
      };
    }
    } catch (e) {
      print('Error detecting pitch: $e');
      return null;
    }
  }

  /// Shifts the pitch of the input file and saves it to the given output path
  static Future<String?> shiftPitch({
    required String inputPath,
    required String outputPath,
    required double semitones,
    bool isVideo = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>(
        
        isVideo ? 'shiftVideoPitchOnly' : 'shiftPitchAudioKit',
        {
          'input': inputPath,
          'output': outputPath,
          'semitones': semitones,
        },
      );

      if (result?['success'] == true) {
        return result?['outputPath'];
      }
    } catch (e) {
      print('Error shifting pitch: $e');
    }
    return null;
  }
  static Future<String?> mergeShiftedAudioWithVideo({
  required String videoPath,
  required String audioPath,
  required String mergedOutputPath,
}) async {
  try {
    // Call the native method to merge the shifted audio with the video

    final result = await _channel.invokeMethod<Map>('mergeShiftedAudioWithVideo', {
      'videoPath': videoPath,
      'audioPath': audioPath,
      'outputPath': mergedOutputPath,
    });

    if (result?['success'] == true) {
      return result?['outputPath'];
    }
  } catch (e) {
    print("Error merging audio with video: $e");
  }
  return null;
}

}

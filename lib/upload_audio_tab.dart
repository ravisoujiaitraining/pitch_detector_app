import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'pitch_shift_panel.dart';
import 'pitch_processing_service.dart';
import 'package:flutter/services.dart';
import 'package:percent_indicator/percent_indicator.dart';
class UploadAudioTab extends StatefulWidget {
  const UploadAudioTab({super.key});

  @override
  State<UploadAudioTab> createState() => _UploadAudioTabState();
}

class _UploadAudioTabState extends State<UploadAudioTab> {
  static const EventChannel _progressChannel =
      EventChannel("com.example.pitch_detector/progress");
static const EventChannel _progressEventChannel = EventChannel('com.example.pitch_detector/progress');
  StreamSubscription? _progressSub;

  String? _filePath;
  String? _fileName;
  String? _originalPitch;
  String? _frequency;
  bool _showProgress = false;
  double _progress = 0.0;
  String _progressPhase = "";

  static const List<String> _validPitches = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'mp4'],
      withData: true,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      setState(() {
        _filePath = path;
        _fileName = name;
        _originalPitch = null;
        _frequency = null;
        _showProgress = true;
        _progress = 0.0;
        _progressPhase = "Detecting pitch...";
      });

      _listenToNativeProgress();

      final pitchResult = await PitchProcessingService.detectPitch(path);

      _progressSub?.cancel();

      final pitch = pitchResult?['note']?.toString();
      final freq = (pitchResult?['frequency'] as double?)?.toStringAsFixed(2);

      setState(() {
  _progressPhase = "Finalizing...";
  _progress = 1.0;
});
await Future.delayed(const Duration(seconds: 1)); // or longer if needed
setState(() => _showProgress = false);

      if (pitch == null || !_validPitches.contains(pitch)) {
        _showErrorDialog("Unsupported pitch detected: ${pitch ?? 'Unknown'}.\nPlease upload a different audio file.");
        return;
      }

      setState(() {
        _originalPitch = pitch;
        _frequency = freq;
      });
    }
  }

  void _listenToNativeProgress() {
    _progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
      if (data is int) {
        setState(() {
          _progress = data / 100.0;
          _progressPhase = "Detecting pitch... $data%";
        });
      }
    }, onError: (error) {
      print("⚠️ EventChannel error: $error");
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invalid Pitch"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(0, 191, 85, 19),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _showProgress ? null : _pickAudioFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color.fromARGB(255, 35, 92, 138)),
                        color: const Color.fromARGB(179, 67, 188, 203),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_rounded, size: 40, color: Colors.white),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Upload Track",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                ".mp3, .wav or .mp4",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_filePath != null && _originalPitch != null)
                    PitchShiftPanel(
                      inputPath: _filePath!,
                      fileName: _fileName!,
                      originalPitch: _originalPitch!,
                      frequency: _frequency,
                    ),
                ],
              ),
            ),
          ),
          if (_showProgress) _buildProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
  return Container(
    color: Colors.black54,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularPercentIndicator(
            radius: 60.0,
            lineWidth: 10.0,
            percent: _progress.clamp(0.0, 1.0), // Ensure between 0 and 1
            animation: true,
            animateFromLastPercent: true,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.tealAccent,
            backgroundColor: Colors.white24,
            center: Text(
              "${(_progress * 100).toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _progressPhase,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    ),
  );
}


}

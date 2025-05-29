import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'pitch_shift_panel.dart';
import 'pitch_processing_service.dart';

class UploadAudioTab extends StatefulWidget {
  const UploadAudioTab({super.key});

  @override
  State<UploadAudioTab> createState() => _UploadAudioTabState();
}

class _UploadAudioTabState extends State<UploadAudioTab> {
  String? _filePath;
  String? _fileName;
  String? _originalPitch;
  String? _frequency;
  bool _showProgress = false;
  double _progress = 0.0;
  String _progressPhase = "";

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'mp4'],
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
        _progress = 0.3;
        _progressPhase = "Detecting pitch...";
      });

      final pitchResult = await PitchProcessingService.detectPitch(path);

      setState(() {
        _originalPitch = pitchResult?['note']?.toString();
        _frequency = (pitchResult?['frequency'] as double?)?.toStringAsFixed(2);
        _progress = 1.0;
        _progressPhase = "Done!";
      });

      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _showProgress = false);
    }
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
                            children:  [
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
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_progressPhase, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text("${(_progress * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

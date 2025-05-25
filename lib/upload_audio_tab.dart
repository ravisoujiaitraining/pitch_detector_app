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
      allowedExtensions: ['mp3', 'wav'],
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: InkWell(
                      onTap: _showProgress ? null : _pickAudioFile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: const Text(
                          "Upload Song",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_filePath != null && _originalPitch != null)
                    PitchShiftPanel(
                      inputPath: _filePath!,
                      fileName: _fileName!,
                      isVideo: false,
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

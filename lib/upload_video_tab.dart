import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'pitch_processing_service.dart';
import 'pitch_shift_panel.dart';

class UploadVideoTab extends StatefulWidget {
  const UploadVideoTab({super.key});

  @override
  State<UploadVideoTab> createState() => _UploadVideoTabState();
}

class _UploadVideoTabState extends State<UploadVideoTab> with TickerProviderStateMixin {
  String? _filePath;
  String? _fileName;
  String? _originalPitch;
  String? _frequency;
  bool _showProgress = false;
  double _progress = 0.0;
  String _progressPhase = "";
  bool _pitchDetected = false;

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4'],
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
        _pitchDetected = false;
      });

      final pitchResult = await PitchProcessingService.detectPitch(path);

      setState(() {
        _originalPitch = pitchResult?['note']?.toString();
        _frequency = (pitchResult?['frequency'] as double?)?.toStringAsFixed(2);
        _progress = 1.0;
        _progressPhase = "Done!";
      });

      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _showProgress = false;
        _pitchDetected = true;
      });
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
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 600),
                    alignment: _pitchDetected ? Alignment.topRight : Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _pitchDetected
                          ? IconButton(
                              key: const ValueKey('icon'),
                              icon: const Icon(Icons.video_library, size: 28, color: Color(0xFF845EC2)),
                              tooltip: 'Re-upload MP4',
                              onPressed: _pickVideoFile,
                            )
                          : InkWell(
                              key: const ValueKey('button'),
                              onTap: _showProgress ? null : _pickVideoFile,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.video_library, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text("Upload MP4", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_filePath != null && _originalPitch != null)
                    PitchShiftPanel(
                      inputPath: _filePath!,
                      fileName: _fileName!,
                      originalPitch: _originalPitch!,
                      frequency: _frequency,
                      isVideo: true,
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

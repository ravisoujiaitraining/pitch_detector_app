import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pitch_processing_service.dart';
import 'gradient_audio_player.dart';
import 'full_screen_video_player.dart';
import 'smart_filename_scroller.dart';

class PitchShiftPanel extends StatefulWidget {
  final String inputPath;
  final String fileName;
  final String originalPitch;
  final String? frequency;

  const PitchShiftPanel({
    super.key,
    required this.inputPath,
    required this.fileName,
    required this.originalPitch,
    this.frequency,
  });

  @override
  State<PitchShiftPanel> createState() => _PitchShiftPanelState();
}

class _PitchShiftPanelState extends State<PitchShiftPanel> {
  final _pitches = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  String? _targetPitch;
  int _sliderShift = 0;
  bool _showProgress = false;
  double _progress = 0.0;
  String _progressPhase = "";
  String? _outputPath;
  String? _mergedVideoPath;
  bool get _isVideo => p.extension(widget.inputPath).toLowerCase() == '.mp4';

  @override
  void initState() {
    super.initState();
    _targetPitch = widget.originalPitch;
  }

  Future<void> _shiftAndSave() async {
    if (_targetPitch == null || _sliderShift == 0) {
      _showErrorDialog("Please adjust the pitch shift.");
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = p.basenameWithoutExtension(widget.fileName);
    final outPath = '${dir.path}/${_targetPitch}_$baseName.wav';

    if (File(outPath).existsSync()) {
      _showPlayerModal(outPath);
      return;
    }

    setState(() {
      _showProgress = true;
      _progress = 0.0;
      _progressPhase = "Shifting pitch...";
    });

    final path = await PitchProcessingService.shiftPitch(
      inputPath: widget.inputPath,
      outputPath: outPath,
      semitones: _sliderShift.toDouble(),
      isVideo: _isVideo,
    );

    setState(() {
      _outputPath = path;
      _progress = 1.0;
      _progressPhase = "Done!";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showProgress = false);

    if (_outputPath != null && File(_outputPath!).existsSync()) {
      _showPlayerModal(_outputPath!);
    }
  }

  Future<void> _downloadShiftedMP4() async {
    if (_targetPitch == null || _sliderShift == 0) {
      _showErrorDialog("Please adjust the pitch shift.");
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = p.basenameWithoutExtension(widget.fileName);
    final shiftedWav = '${dir.path}/${_targetPitch}_$baseName.wav';
    final finalMp4 = '${dir.path}/${_targetPitch}_$baseName.mp4';

    if (File(finalMp4).existsSync()) {
      _showMergedVideoPlayer(finalMp4);
      return;
    }

    setState(() {
      _showProgress = true;
      _progress = 0.0;
      _progressPhase = "Generating shifted MP4...";
    });

    final audioPath = File(shiftedWav).existsSync()
        ? shiftedWav
        : await PitchProcessingService.shiftPitch(
            inputPath: widget.inputPath,
            outputPath: shiftedWav,
            semitones: _sliderShift.toDouble(),
            isVideo: true,
          );

    final mergedPath = await PitchProcessingService.mergeShiftedAudioWithVideo(
      videoPath: widget.inputPath,
      audioPath: audioPath!,
      mergedOutputPath: finalMp4,
    );

    setState(() {
      _mergedVideoPath = mergedPath;
      _progress = 1.0;
      _progressPhase = "Done!";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showProgress = false);

    if (mergedPath != null) {
      _showMergedVideoPlayer(mergedPath);
    }
  }

  void _showPlayerModal(String path) {
    final fileName = p.basename(path);
    if (p.extension(path).toLowerCase() == '.mp4') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullscreenVideoPlayer(
            videoPath: path,
            autoPlay: true,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GradientAudioPlayer(
            outputPath: path,
            fileName: fileName,
            autoPlay: true,
            showHeader: false,
          ),
        ),
      );
    }
  }

  void _showMergedVideoPlayer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPlayer(
          videoPath: path,
          autoPlay: true,
        ),
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  Widget _styledCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: child,
    );
  }

  Widget _styledButton({required String text, required IconData icon, required VoidCallback onTap}) {
    return Center(
      child: InkWell(
        onTap: onTap,
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
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileName;

    return Stack(
      children: [
        SingleChildScrollView(
          child: _styledCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Row(
        children: [
           Icon(_isVideo ? Icons.video_library : Icons.audiotrack, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: SmartFilenameScroller(
              text: p.basename(widget.inputPath),
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              width: MediaQuery.of(context).size.width * 0.5,
              scroll: false,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
            onPressed: () => _showPlayerModal(widget.inputPath),
          ),
        ],
      ),
    ),
                const SizedBox(height: 16),
                Text("Detected: ${widget.originalPitch} (${widget.frequency ?? ""} Hz)",
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Select Target Pitch", style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _targetPitch,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          dropdownColor: const Color(0xFF845EC2),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          onChanged: (p) {
                            setState(() {
                              _targetPitch = p;
                              _sliderShift = _pitches.indexOf(p!) - _pitches.indexOf(widget.originalPitch);
                            });
                          },
                          items: _pitches.map((p) {
                            return DropdownMenuItem(value: p, child: Text(p));
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Pitch shift: $_sliderShift semitones", style: const TextStyle(color: Colors.white, fontSize: 18)),
                Slider(
                  value: _sliderShift.toDouble(),
                  min: -12,
                  max: 12,
                  divisions: 24,
                  label: '$_sliderShift',
                  onChanged: (v) {
                    final shift = v.toInt();
                    setState(() {
                      _sliderShift = shift;
                      _targetPitch = _pitches[(_pitches.indexOf(widget.originalPitch) + shift + 12) % 12];
                    });
                  },
                ),
                const SizedBox(height: 16),
              Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Expanded(
      child: _styledButton(
        text: "MP3",
        icon: Icons.download,
        onTap: _shiftAndSave,
      ),
    ),
    if (_isVideo) ...[
      const SizedBox(width: 16),
      Expanded(
        child: _styledButton(
          text: "MP4",
          icon: Icons.file_download,
          onTap: _downloadShiftedMP4,
        ),
      ),
    ],
  ],
),
              ],
            ),
          ),
        ),
        if (_showProgress)
          Container(
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
          ),
      ],
    );
  }
}

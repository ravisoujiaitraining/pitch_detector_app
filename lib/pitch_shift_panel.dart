import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'pitch_processing_service.dart';
import 'gradient_audio_player.dart';
import 'video_preview_player.dart';
import 'package:path/path.dart' as p;

class PitchShiftPanel extends StatefulWidget {
  final String inputPath;
  final String fileName;
  final String originalPitch;
  final String? frequency;
  final bool isVideo;

  const PitchShiftPanel({
    super.key,
    required this.inputPath,
    required this.fileName,
    required this.originalPitch,
    this.frequency,
    this.isVideo = false,
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

  @override
  void initState() {
    super.initState();
    _targetPitch = widget.originalPitch;
  }

  void _showOriginalPlayerModal() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GradientAudioPlayer(
          outputPath: widget.inputPath,
          fileName: widget.fileName,
          autoPlay: true,
        ),
      ),
    );
  }

  Future<void> _shiftAndSave() async {
    if (_targetPitch == null || _sliderShift == 0) {
      _showErrorDialog(
        "Please adjust the pitch. Shift value (Semitone) cannot be 0 and the detected pitch cannot be the same as target pitch.",
      );
      return;
    }

    setState(() {
      _showProgress = true;
      _progress = 0.0;
      _progressPhase = "Shifting pitch...";
    });

    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/shifted_${widget.fileName}.wav';

    final path = await PitchProcessingService.shiftPitch(
      inputPath: widget.inputPath,
      outputPath: outPath,
      semitones: _sliderShift.toDouble(),
      isVideo: widget.isVideo,
    );

    setState(() {
      _outputPath = path;
      _progress = 1.0;
      _progressPhase = "Done!";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showProgress = false);
  }
void _showMergedVideoPlayer(String path) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Center(
            child: VideoPreviewPlayer(
              videoPath: path,
              autoPlay: true, // ensure this param exists in your VideoPreviewPlayer
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Future<void> _mergeAudioToVideo() async {
    if (_outputPath == null) return;

    setState(() {
      _showProgress = true;
      _progress = 0.0;
      _progressPhase = "Merging video with new pitch...";
    });

    final dir = await getApplicationDocumentsDirectory();
    final mergedOutputPath = '${dir.path}/${widget.fileName}_merged.mp4';

    final mergedPath = await PitchProcessingService.mergeShiftedAudioWithVideo(
      videoPath: widget.inputPath,
      audioPath: _outputPath!,
      mergedOutputPath: mergedOutputPath,
    );

    setState(() {
      _outputPath = mergedPath;
      _mergedVideoPath = mergedPath;
      _progress = 1.0;
      _progressPhase = "Done!";
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showProgress = false);

    if (mergedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to merge audio with video")),
      );
    } 
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
    return Stack(
      children: [
        SingleChildScrollView(
          child: _styledCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⬇ New song title with play icon
              GradientAudioPlayer(outputPath: widget.inputPath, fileName: widget.fileName),

                const SizedBox(height: 16),
                Text("Detected: ${widget.originalPitch} (${widget.frequency ?? ""} Hz)",
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                const Text("Select Target Pitch", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _targetPitch,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      onChanged: (p) {
                        setState(() {
                          _targetPitch = p;
                          _sliderShift = _pitches.indexOf(p!) - _pitches.indexOf(widget.originalPitch);
                        });
                      },
                      items: _pitches.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    ),
                  ),
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
                _styledButton(text: "Save Shifted Pitch", icon: Icons.save_alt, onTap: _shiftAndSave),
                const SizedBox(height: 16),

                if (_outputPath != null && File(_outputPath!).existsSync())
                  GradientAudioPlayer(outputPath: _outputPath!, fileName: widget.fileName),

                if (widget.isVideo && _outputPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _styledButton(
                      text: "Attach to Video",
                      icon: Icons.video_call,
                      onTap: _mergeAudioToVideo,
                    ),
                  ),

                if (_mergedVideoPath != null && File(_mergedVideoPath!).existsSync()) ...[
  const SizedBox(height: 24),
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.video_file, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          p.basename(_mergedVideoPath!),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.play_circle_fill, size: 32, color: Colors.teal),
        onPressed: () => _showMergedVideoPlayer(_mergedVideoPath!),
      ),
    ],
  ),
],
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

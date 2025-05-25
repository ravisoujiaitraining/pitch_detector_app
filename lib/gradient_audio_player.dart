import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class GradientAudioPlayer extends StatefulWidget {
  final String outputPath;
  final String fileName;
  final bool autoPlay;

  const GradientAudioPlayer({
    super.key,
    required this.outputPath,
    required this.fileName,
    this.autoPlay = false,
  });

  @override
  State<GradientAudioPlayer> createState() => _GradientAudioPlayerState();
}

class _GradientAudioPlayerState extends State<GradientAudioPlayer> {
  void _showPlayerModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: _AudioPlayerUI(
          outputPath: widget.outputPath,
          fileName: widget.fileName,
          autoPlay: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Icon(Icons.audiotrack, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              p.basename(widget.outputPath),
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              softWrap: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
            onPressed: () => _showPlayerModal(context),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayerUI extends StatefulWidget {
  final String outputPath;
  final String fileName;
  final bool autoPlay;

  const _AudioPlayerUI({
    required this.outputPath,
    required this.fileName,
    required this.autoPlay,
  });

  @override
  State<_AudioPlayerUI> createState() => _AudioPlayerUIState();
}

class _AudioPlayerUIState extends State<_AudioPlayerUI> with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  Duration _total = Duration.zero;
  Duration _pos = Duration.zero;
  bool _isPlaying = false;

  late AnimationController _waveController;
  late List<double> _waveHeights;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveHeights = List.generate(60, (_) => Random().nextDouble());

    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      setState(() {
        _waveHeights = List.generate(60, (_) => Random().nextDouble());
      });
    });

    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    try {
      await _player.setFilePath(widget.outputPath);
      _total = _player.duration ?? Duration.zero;
      _player.positionStream.listen((d) {
        if (mounted) setState(() => _pos = d);
      });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
      });

      if (widget.autoPlay) _player.play();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _downloadFileWithPrompt() async {
    final TextEditingController nameController = TextEditingController(text: widget.fileName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save As"),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: "File name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text("Save")),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final newPath = '${dir.path}/$result';
        await File(widget.outputPath).copy(newPath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ File saved to $newPath")),
        );
      } catch (e) {
        debugPrint("Download error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.fileName,
              style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _waveHeights
                  .map((h) => Container(
                        width: 3,
                        height: 12 + h * 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _pos.inMilliseconds.toDouble().clamp(0, _total.inMilliseconds.toDouble()),
            max: _total.inMilliseconds.toDouble(),
            onChanged: (val) => _player.seek(Duration(milliseconds: val.toInt())),
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(_pos), style: const TextStyle(color: Colors.white)),
              Text(_format(_total), style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 48, color: Colors.white),
                onPressed: () => _isPlaying ? _player.pause() : _player.play(),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 32, color: Colors.white),
                onPressed: _downloadFileWithPrompt,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 32, color: Colors.white),
                onPressed: () {
                  Share.shareXFiles([XFile(widget.outputPath)], text: "Listen to this audio!");
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 32, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

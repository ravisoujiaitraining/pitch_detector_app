import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'smart_filename_scroller.dart';
import 'upload_page.dart';
import 'share_file.dart';
class GradientAudioPlayer extends StatefulWidget {
  final String outputPath;
  final String fileName;
  final bool autoPlay;
  final bool showHeader;

  const GradientAudioPlayer({
    super.key,
    required this.outputPath,
    required this.fileName,
    this.autoPlay = false,
    this.showHeader = true,
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
          showHeader: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showHeader) {
      return _AudioPlayerUI(
        outputPath: widget.outputPath,
        fileName: widget.fileName,
        autoPlay: widget.autoPlay,
        showHeader: false,
      );
    }

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
            child: SmartFilenameScroller(
              text: p.basename(widget.outputPath),
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              width: MediaQuery.of(context).size.width * 0.5,
              scroll: false,
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
  final bool showHeader;

  const _AudioPlayerUI({
    required this.outputPath,
    required this.fileName,
    required this.autoPlay,
    required this.showHeader,
  });

  @override
  State<_AudioPlayerUI> createState() => _AudioPlayerUIState();
}

class _AudioPlayerUIState extends State<_AudioPlayerUI> with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  Duration _total = Duration.zero;
  Duration _pos = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  bool _muted = false;

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
      if (_isPlaying && mounted) {
        setState(() {
          _waveHeights = List.generate(60, (_) => Random().nextDouble());
        });
      }
    });

    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    try {
      await _player.setFilePath(widget.outputPath);
      _total = _player.duration ?? Duration.zero;
      _player.setVolume(_volume);

      _player.positionStream.listen((d) {
        if (mounted) setState(() => _pos = d);
      });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
      });

      if (widget.autoPlay) _player.play();
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }
Future<String> saveLocalCopy(String filePath) async {
  final appDir = await getApplicationDocumentsDirectory();
  final fileName = filePath.split('/').last;
  final newPath = '${appDir.path}/$fileName';

  final sourceFile = File(filePath);
  await sourceFile.copy(newPath);

  return newPath;
}
  String _format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final marqueeWidth = MediaQuery.of(context).size.width * 0.7;

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
          SmartFilenameScroller(
            text: widget.fileName,
            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            width: marqueeWidth,
            scroll: _isPlaying,
          ),
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
            children: [
              const Icon(Icons.volume_up, color: Colors.white),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  onChanged: (val) {
                    setState(() {
                      _volume = val;
                      _muted = val == 0;
                      _player.setVolume(_volume);
                    });
                  },
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 48, color: Colors.white),
                onPressed: () => _isPlaying ? _player.pause() : _player.play(),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  _muted || _volume == 0 ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    if (_volume > 0) {
                      _volume = 0;
                      _muted = true;
                    } else {
                      _volume = 1.0;
                      _muted = false;
                    }
                    _player.setVolume(_volume);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 32, color: Colors.white),
                onPressed: () async {
                      shareFile(context,widget.outputPath);

                    /*final localCopyPath = await saveLocalCopy(widget.outputPath);

                 
                  await Share.shareXFiles([XFile(localCopyPath)], text: "🎵 Check out this pitch-shifted audio!");
                */
                mediaControlKey.currentState?.refreshMediaList();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 32, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'smart_filename_scroller.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Duration startPosition;
  final bool autoPlay;
  final bool showHeader;

  const FullscreenVideoPlayer({
    super.key,
    required this.videoPath,
    this.startPosition = Duration.zero,
    this.autoPlay = false,
    this.showHeader = false,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  double _volume = 0.75;
  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    final controller = VideoPlayerController.file(File(widget.videoPath));
    await controller.initialize();
    controller.setLooping(true);
    controller.setVolume(_volume);
    await controller.seekTo(widget.startPosition);

    if (widget.autoPlay) {
      controller.play();
      _isPlaying = true;
    }

    _controllerListener = () {
      if (!mounted) return;
      final isPlayingNow = controller.value.isPlaying;
      if (_isPlaying != isPlayingNow) {
        setState(() => _isPlaying = isPlayingNow);
      } else {
        setState(() {}); // For progress updates
      }
    };

    controller.addListener(_controllerListener!);

    setState(() {
      _controller = controller;
    });
  }

  @override
  void dispose() {
    if (_controller != null && _controllerListener != null) {
      _controller!.removeListener(_controllerListener!);
    }
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller!.play() : _controller!.pause();
    });
  }

  String _formatDuration(Duration d) =>
      "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final fileName = p.basename(widget.videoPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: controller != null && controller.value.isInitialized
          ? GestureDetector(
              onTap: _togglePlayPause,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),

                  // 🔤 Header with SmartFilenameScroller
                  //if (widget.showHeader)
                    Positioned(
                      top: 40,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.video_library, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SmartFilenameScroller(
                              text: fileName,
                              scroll: _isPlaying,
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                              width: MediaQuery.of(context).size.width * 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ⏱️ Time Slider
                  Positioned(
                    bottom: 140,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Slider(
                          value: controller.value.position.inSeconds.toDouble(),
                          min: 0,
                          max: controller.value.duration.inSeconds.toDouble(),
                          onChanged: (value) =>
                              controller.seekTo(Duration(seconds: value.toInt())),
                        ),
                        Text(
                          "${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // 🔊 Volume Slider
                  Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: Row(
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
                                controller.setVolume(val);
                              });
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🎛️ Control Buttons
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                          onPressed: () {
                            final newPos = controller.value.position -
                                const Duration(seconds: 10);
                            controller.seekTo(newPos >= Duration.zero
                                ? newPos
                                : Duration.zero);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle : Icons.play_circle,
                            size: 40,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, color: Colors.white),
                          onPressed: () {
                            final newPos = controller.value.position +
                                const Duration(seconds: 10);
                            controller.seekTo(newPos <= controller.value.duration
                                ? newPos
                                : controller.value.duration);
                          },
                        ),

                        // 📤 Share
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () async {
                            await Share.shareXFiles(
                              [XFile(widget.videoPath)],
                              text: "🎥 Check out this pitch-shifted video!",
                            );
                          },
                        ),

                        // ❌ Close
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

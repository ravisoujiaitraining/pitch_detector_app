import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector_io.dart';

class VideoPreviewPlayer extends StatefulWidget {
  final String videoPath;
  final bool autoPlay;

  const VideoPreviewPlayer({
    super.key,
    required this.videoPath,
    this.autoPlay = false,
  });

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.setLooping(true);
        if (widget.autoPlay) _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreenModal(BuildContext context) async {
    _controller.pause();
    _currentPosition = _controller.value.position;

    await showDialog(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (_) => FullscreenVideoWrapper(
        videoPath: widget.videoPath,
        startPosition: _currentPosition,
        autoPlay: true,
      ),
    );

    setState(() {
      _controller.seekTo(_currentPosition);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurpleAccent.withOpacity(0.7), Colors.tealAccent.withOpacity(0.7)],
                          ),
                        ),
                        child: const Center(child: Text("Waveform Visual Placeholder", style: TextStyle(color: Colors.white, fontSize: 12))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, size: 28, color: Colors.white),
                    onPressed: () => _openFullscreenModal(context),
                  ),
                ],
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}

class FullscreenVideoWrapper extends StatelessWidget {
  final String videoPath;
  final Duration startPosition;
  final bool autoPlay;

  const FullscreenVideoWrapper({
    super.key,
    required this.videoPath,
    required this.startPosition,
    this.autoPlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FullscreenVideoPlayer(
          videoPath: videoPath,
          startPosition: startPosition,
          autoPlay: autoPlay,
        ),
      ),
    );
  }
}

class FullscreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  final Duration startPosition;
  final bool autoPlay;

  const FullscreenVideoPlayer({
    super.key,
    required this.videoPath,
    required this.startPosition,
    this.autoPlay = false,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isLooping = true;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _controller.seekTo(widget.startPosition);
        _controller.setLooping(_isLooping);
        if (widget.autoPlay) _controller.play();
        setState(() => _isPlaying = widget.autoPlay);
      });
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  Future<void> _downloadVideo() async {
    final suggestedName = File(widget.videoPath).uri.pathSegments.last;
    final path = await getSavePath(suggestedName: suggestedName);

    if (path != null) {
      try {
        final file = File(widget.videoPath);
        await file.copy(path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Saved to: $path')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to save video')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controller.value.duration;
    final position = _controller.value.position;

    return _controller.value.isInitialized
        ? GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 28, color: Colors.redAccent),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Slider(
                        value: position.inSeconds.toDouble(),
                        min: 0,
                        max: duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          _controller.seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                      Text(
                        "${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / "
                        "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () {
                          final pos = _controller.value.position;
                          _controller.seekTo(pos - const Duration(seconds: 10));
                        },
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 40, color: Colors.white),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () {
                          final pos = _controller.value.position;
                          _controller.seekTo(pos + const Duration(seconds: 10));
                        },
                      ),
                      IconButton(
                        icon: Icon(_isLooping ? Icons.repeat_on : Icons.repeat, color: Colors.white),
                        onPressed: () {
                          setState(() => _isLooping = !_isLooping);
                          _controller.setLooping(_isLooping);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () {
                          Share.shareXFiles([XFile(widget.videoPath)], text: 'Check out this pitch-shifted video!');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: _downloadVideo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}

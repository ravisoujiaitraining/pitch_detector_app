import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'full_screen_video_player.dart';
import 'smart_filename_scroller.dart';

class GradientVideoPlayer extends StatelessWidget {
  final String videoPath;
  final bool autoPlay;
  final bool showHeader;

  const GradientVideoPlayer({
    super.key,
    required this.videoPath,
    this.autoPlay = false,
    this.showHeader = true,
  });

  void _showVideoModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPlayer(
          videoPath: videoPath,
          autoPlay: autoPlay,
          showHeader: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(videoPath);

    if (!showHeader) {
      return FullscreenVideoPlayer(
        videoPath: videoPath,
        autoPlay: autoPlay,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.video_library, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: SmartFilenameScroller(
              text: fileName,
              scroll: false,
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              width: MediaQuery.of(context).size.width * 0.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
            onPressed: () => _showVideoModal(context),
          ),
        ],
      ),
    );
  }
}

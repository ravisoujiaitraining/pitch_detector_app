import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'gradient_audio_player.dart';
import 'full_screen_video_player.dart';
import 'smart_filename_scroller.dart';

class MediaControlTab extends StatefulWidget {
  const MediaControlTab({super.key});

  @override
  State<MediaControlTab> createState() => _MediaControlTabState();
}

class _MediaControlTabState extends State<MediaControlTab> {
  List<FileSystemEntity> _allFiles = [];
  List<FileSystemEntity> _filteredFiles = [];
  String _filterText = "";

  @override
  void initState() {
    super.initState();
    _loadMediaFiles();
  }

  Future<void> _loadMediaFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync(recursive: true);

    final mediaFiles = files.where((f) {
      final ext = p.extension(f.path).toLowerCase();
      return ['.mp3', '.wav', '.mp4'].contains(ext);
    }).toList();

    setState(() {
      _allFiles = mediaFiles;
      _applyFilter();
    });
  }

  void _applyFilter() {
    setState(() {
      _filteredFiles = _allFiles.where((f) {
        final name = p.basename(f.path).toLowerCase();
        return name.contains(_filterText.toLowerCase());
      }).toList();
    });
  }

  Widget _buildFileTile(FileSystemEntity file) {
    final path = file.path;
    final fileName = p.basename(path);
    final ext = p.extension(path).toLowerCase();
    final isVideo = ext == '.mp4';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF845EC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(isVideo ? Icons.video_library : Icons.audiotrack,
              color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: SmartFilenameScroller(
              text: fileName,
              scroll: false,
              width: MediaQuery.of(context).size.width * 0.5,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill,
                color: Colors.white, size: 32),
            onPressed: () {
              if (isVideo) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenVideoPlayer(
                      videoPath: path,
                      autoPlay: true,
                      showHeader: true,
                    ),
                  ),
                );
              } else {
                showDialog(
                  context: context,
                  barrierDismissible: true,
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
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 🔍 Filter Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "Filter",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _filterText = value;
                _applyFilter();
              },
            ),
          ),

          // 📄 List of Files
          Expanded(
            child: _filteredFiles.isEmpty
                ? const Center(
                    child: Text(
                      "No media files found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredFiles.length,
                    itemBuilder: (context, index) =>
                        _buildFileTile(_filteredFiles[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

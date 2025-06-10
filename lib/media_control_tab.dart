import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'share_file.dart';
import 'gradient_audio_player.dart';
import 'full_screen_video_player.dart';
import 'smart_filename_scroller.dart';

enum SortBy { name, size, date }
enum MediaFilter { all, mp3, wav, mp4 }

class MediaControlTab extends StatefulWidget {
  const MediaControlTab({super.key});
  @override
  State<MediaControlTab> createState() => MediaControlTabState();
}

class MediaControlTabState extends State<MediaControlTab> {
  List<FileSystemEntity> _mediaFiles = [];
  String _filter = "";
  bool _multiSelectMode = false;
  Set<String> _selectedPaths = {};
  SortBy _sortBy = SortBy.name;
  bool _ascending = true;
  bool _selectAllToggled = false;
  MediaFilter _mediaFilter = MediaFilter.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMediaFiles();
  }

  void refreshMediaList() => _loadMediaFiles();

  Future<void> _loadMediaFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync(recursive: true, followLinks: false);
    final filtered = files.where((file) {
      final name = p.basename(file.path).toLowerCase();
      return name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.mp4');
    }).toList();
    setState(() {
      _mediaFiles = _sortFiles(filtered);
    });
  }

  List<FileSystemEntity> _sortFiles(List<FileSystemEntity> files) {
    files.sort((a, b) {
      switch (_sortBy) {
        case SortBy.name:
          return _ascending
              ? p.basename(a.path).compareTo(p.basename(b.path))
              : p.basename(b.path).compareTo(p.basename(a.path));
        case SortBy.size:
          return _ascending
              ? File(a.path).lengthSync().compareTo(File(b.path).lengthSync())
              : File(b.path).lengthSync().compareTo(File(a.path).lengthSync());
        case SortBy.date:
          return _ascending
              ? File(a.path).lastModifiedSync().compareTo(File(b.path).lastModifiedSync())
              : File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      }
    });
    return files;
  }

  void _applySort(SortBy sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _ascending = !_ascending;
      } else {
        _sortBy = sortBy;
        _ascending = true;
      }
      _mediaFiles = _sortFiles(_mediaFiles);
    });
  }

  Future<String> _getDurationAndSize(String path) async {
    final file = File(path);
    final sizeMB = (await file.length()) / (1024 * 1024);
    String durationStr = "Unknown";
    try {
      if (path.endsWith(".mp4")) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        final seconds = controller.value.duration.inSeconds;
        durationStr = "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";
        controller.dispose();
      } else {
        final player = AudioPlayer();
        await player.setFilePath(path);
        final seconds = player.duration?.inSeconds ?? 0;
        durationStr = "${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}";
        await player.dispose();
      }
    } catch (_) {}
    return "Duration: $durationStr • Size: ${sizeMB.toStringAsFixed(1)} MB";
  }

  Future<void> _confirmAndDeleteFile(String path) async {
    final fileName = p.basename(path);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete File"),
        content: Text("Are you sure you want to delete:\n\n$fileName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        refreshMediaList();
      }
    }
  }

  Future<void> _confirmAndDeleteSelectedFiles() async {
    if (_selectedPaths.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Selected Files"),
        content: Text("Are you sure you want to delete ${_selectedPaths.length} selected file(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      for (var path in _selectedPaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _multiSelectMode = false;
        _selectedPaths.clear();
        _selectAllToggled = false;
      });
      refreshMediaList();
    }
  }

  Icon _mediaIcon(MediaFilter filter) {
    switch (filter) {
      case MediaFilter.mp3:
        return const Icon(Icons.music_note);
      case MediaFilter.wav:
        return const Icon(Icons.multitrack_audio);
      case MediaFilter.mp4:
        return const Icon(Icons.videocam);
      default:
        return const Icon(Icons.library_music);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _mediaFiles.where((file) {
      final name = p.basename(file.path).toLowerCase();
      final matches = _mediaFilter == MediaFilter.all ||
          (_mediaFilter == MediaFilter.mp3 && name.endsWith(".mp3")) ||
          (_mediaFilter == MediaFilter.wav && name.endsWith(".wav")) ||
          (_mediaFilter == MediaFilter.mp4 && name.endsWith(".mp4"));
      return matches && name.contains(_filter.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header row (search, sort, filter)
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _filter = v),
                    decoration: const InputDecoration(
                      hintText: "Search...",
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.deepPurple),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: SortBy.values.map((s) {
                      return ListTile(
                        title: Text("Sort by ${s.name}"),
                        trailing: _sortBy == s
                            ? Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward)
                            : null,
                        onTap: () {
                          _applySort(s);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "multi-delete") {
                    setState(() {
                      _multiSelectMode = true;
                      _selectedPaths.clear();
                      _selectAllToggled = false;
                    });
                  } else if (value.startsWith("filter:")) {
                    setState(() {
                      _mediaFilter = MediaFilter.values.firstWhere((e) => e.name == value.split(":")[1]);
                    });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: "multi-delete",
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Delete Multiple"),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  ...MediaFilter.values.map((f) => PopupMenuItem(
                        value: "filter:${f.name}",
                        child: Row(children: [
                          _mediaIcon(f),
                          const SizedBox(width: 8),
                          Text(f.name.toUpperCase()),
                          if (_mediaFilter == f) ...[
                            const Spacer(),
                            const Icon(Icons.check, color: Colors.green, size: 18),
                          ]
                        ]),
                      )),
                ],
              )
            ],
          ),

          if (_multiSelectMode)
            Row(
              children: [
                TextButton.icon(
                  icon: Icon(_selectAllToggled ? Icons.remove_done : Icons.select_all),
                  label: Text(_selectAllToggled ? "Deselect All" : "Select All"),
                  onPressed: () {
                    setState(() {
                      if (_selectAllToggled) {
                        _selectedPaths.clear();
                      } else {
                        _selectedPaths = filtered.map((f) => f.path).toSet();
                      }
                      _selectAllToggled = !_selectAllToggled;
                    });
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Back"),
                  onPressed: () {
                    setState(() {
                      _multiSelectMode = false;
                      _selectedPaths.clear();
                      _selectAllToggled = false;
                    });
                  },
                ),
              ],
            ),

          const SizedBox(height: 8),

          if (filtered.isEmpty)
            const Expanded(child: Center(child: Text("No media files found.", style: TextStyle(color: Colors.black54))))
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final file = filtered[index];
                  final path = file.path;
                  final fileName = p.basename(path);
                  final isVideo = path.endsWith(".mp4");
                  final isSelected = _selectedPaths.contains(path);
                  final shareKey = GlobalKey();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: _multiSelectMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedPaths.add(path);
                                } else {
                                  _selectedPaths.remove(path);
                                }
                              });
                            },
                          )
                        : Icon(isVideo ? Icons.video_library : Icons.audiotrack, color: Colors.teal),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SmartFilenameScroller(
                          text: fileName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          width: MediaQuery.of(context).size.width * 0.55,
                          scroll: false,
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<String>(
                          future: _getDurationAndSize(path),
                          builder: (_, snap) => Text(
                            snap.data ?? "Loading...",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_multiSelectMode)
                          IconButton(
                            key: shareKey,
                            icon: const Icon(Icons.share, color: Colors.indigo),
                            onPressed: () {
                              final box = shareKey.currentContext?.findRenderObject() as RenderBox?;
                              final origin = (box != null && box.hasSize)
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : Rect.fromCenter(
                                      center: Offset(
                                        MediaQuery.of(context).size.width / 2,
                                        MediaQuery.of(context).size.height / 2,
                                      ),
                                      width: 0,
                                      height: 0,
                                    );
                              safeShareFileMediaTab(context, path, origin);
                            },
                          ),
                        if (!_multiSelectMode)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmAndDeleteFile(path),
                          ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Colors.deepPurple, size: 32),
                          onPressed: () {
                            if (isVideo) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenVideoPlayer(videoPath: path, autoPlay: true),
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
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
                },
              ),
            ),

          if (_multiSelectMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text("Delete Selected"),
                onPressed: _selectedPaths.isEmpty ? null : _confirmAndDeleteSelectedFiles,
              ),
            ),
        ],
      ),
    );
  }
}

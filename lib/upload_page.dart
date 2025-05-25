import 'package:flutter/material.dart';
import 'upload_audio_tab.dart';
import 'upload_video_tab.dart';
import 'upload_youtube_tab.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with TickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 0;

  final List<Widget> _tabViews = const [
    UploadAudioTab(),
    UploadVideoTab(),
    UploadYouTubeTab(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabViews.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Upload'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'MP3/WAV'),
            Tab(text: 'MP4'),
            Tab(text: 'YouTube'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabViews,
      ),
    );
  }
}

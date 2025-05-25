import 'package:flutter/material.dart';

class UploadYouTubeTab extends StatelessWidget {
  const UploadYouTubeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Paste a YouTube link to extract and process audio.',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

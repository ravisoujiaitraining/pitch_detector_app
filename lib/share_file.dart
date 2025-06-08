import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

Future<void> shareFile(BuildContext context, String filePath) async {
  final tempDir = await getTemporaryDirectory();
  final filename = path.basename(filePath);
  final tempPath = '${tempDir.path}/$filename';

  try {
    await File(filePath).copy(tempPath);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      print("❌ Invalid RenderBox. Skipping share.");
      return;
    }
    await Share.shareXFiles(
      [XFile(tempPath)],
      text: 'Here is your pitch-shifted track 🎵',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
  } catch (e) {
    print("❌ Error sharing file: $e");
  }
}

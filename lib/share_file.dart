import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

Future<void> shareFile(BuildContext context, String filePath) async {
  print("📤 Sharing file: $filePath");
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
Future<void> safeShareFileMediaTab(BuildContext context,String filePath, Rect origin) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) throw Exception("File not found.");

    final tempDir = await getTemporaryDirectory();
    final safeName = path.basename(filePath);
    final safePath = path.join(tempDir.path, safeName);
    final safeFile = await file.copy(safePath);

    await Share.shareXFiles(
      [XFile(safeFile.path)],
      text: "🎬 Here's your pitch-shifted media!",
      sharePositionOrigin: origin,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Share failed: $e")),
    );
  }
}

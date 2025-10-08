import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';

class TopicStorage {
  static Future<String?> getDownloadsPath() async {
    if (await Permission.manageExternalStorage.request().isGranted ||
        await Permission.storage.request().isGranted) {
      String path = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD);

      final dir = Directory('$path/SLT');
      if (!await dir.exists()) await dir.create(recursive: true);

      return dir.path;
    }
    return null;
  }

  static Future<void> saveTopic(String topic) async {
    final dirPath = await getDownloadsPath();
    if (dirPath == null) return;

    final file = File('$dirPath/topic.txt');
    await file.writeAsString(topic);
    print("✅ Saved topic to ${file.path}");
  }

  static Future<String?> loadTopic() async {
    final dirPath = await getDownloadsPath();
    if (dirPath == null) return null;

    final file = File('$dirPath/topic.txt');
    if (await file.exists()) return await file.readAsString();
    return null;
  }
}

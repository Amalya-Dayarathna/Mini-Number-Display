import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';

/// Handles loading MQTT topic from device storage
/// Reads device identifier from topic.txt and builds full topic dynamically
class TopicStorage {
  /// Gets the Downloads/SLT directory path with proper permissions
  static Future<String?> getDownloadsPath() async {
    // Check if permissions are already granted, request only if needed
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.request().isGranted ||
        await Permission.storage.request().isGranted) {
      // Get the Downloads folder path
      String path = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD);

      // Create SLT subfolder if it doesn't exist
      final dir = Directory('$path/SLT');
      if (!await dir.exists()) await dir.create(recursive: true);

      return dir.path;
    }
    return null; // Permission denied
  }

  /// Reads device ID from topic.txt and builds full MQTT topic
  /// Returns full topic like "QMS/2/1/NEXT_TOKEN_RESPONSE"
  static Future<String?> loadTopic() async {
    final dirPath = await getDownloadsPath();
    if (dirPath == null) return null; // No permission or path unavailable

    final file = File('$dirPath/topic.txt');
    if (await file.exists()) {
      final deviceId = await file.readAsString().then((value) => value.trim());
      return 'QMS/$deviceId/NEXT_TOKEN_RESPONSE';
    }
    return null; // File doesn't exist
  }

  /// Gets all token display topics for subscription
  /// Returns list of topics: NEXT_TOKEN_RESPONSE, RECALLED_RESPONSE, SEATED_RESPONSE, AGENT_INITIAL_RESPONSE
  static Future<List<String>?> loadAllTokenTopics() async {
    final dirPath = await getDownloadsPath();
    if (dirPath == null) return null;

    final file = File('$dirPath/topic.txt');
    if (await file.exists()) {
      final deviceId = await file.readAsString().then((value) => value.trim());
      return [
        'QMS/$deviceId/NEXT_TOKEN_RESPONSE',
        'QMS/$deviceId/RECALLED_RESPONSE',
        'QMS/$deviceId/SEATED_RESPONSE',
        'QMS/$deviceId/AGENT_INITIAL_RESPONSE',
        'QMS/$deviceId/BREAK_RESPONSE',
      ];
    }
    return null;
  }
}

import 'dart:convert';
import 'dart:io' show Platform, File, Directory;
import 'package:path_provider/path_provider.dart';

/// Mobile/Desktop-specific file download implementation
class FileDownloadHelper {
  static Future<String?> downloadFile({
    required String content,
    required String filename,
    String? mimeType,
  }) async {
    try {
      final bytes = utf8.encode(content);
      
      // Get the appropriate directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          directory = Directory('${directory.path}/../Download');
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final homeDir = Platform.environment['USERPROFILE'] ?? 
                       Platform.environment['HOME'] ?? '';
        if (homeDir.isNotEmpty) {
          directory = Directory('$homeDir/Downloads');
        }
      }
      
      if (directory == null || !await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);
      
      return file.path;
    } catch (e) {
      return 'Error: $e';
    }
  }
}

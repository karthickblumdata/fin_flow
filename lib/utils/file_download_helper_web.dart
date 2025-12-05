import 'dart:convert';
import 'dart:html' as html;

/// Web-specific file download implementation
class FileDownloadHelper {
  static Future<String?> downloadFile({
    required String content,
    required String filename,
    String? mimeType,
  }) async {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType ?? 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded successfully';
    } catch (e) {
      return 'Error: $e';
    }
  }
}

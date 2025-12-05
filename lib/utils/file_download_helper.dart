// Conditional export - exports web implementation for web, mobile for others
export 'file_download_helper_web.dart' if (dart.library.io) 'file_download_helper_mobile.dart';
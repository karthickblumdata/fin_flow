/// Utility class for extracting profile image URLs from user data
class ProfileImageHelper {
  /// Extracts profile image URL from user data by checking multiple possible field names
  /// 
  /// Checks for: profileImage, profileUrl, avatar, avatarUrl, photo, profilePic,
  /// image, profilePhoto, profileImageUrl
  /// 
  /// Returns the first non-empty string value found, or null if none found
  static String? extractImageUrl(Map<String, dynamic> user) {
    final possibleKeys = [
      'profileImage',
      'profileUrl',
      'avatar',
      'avatarUrl',
      'photo',
      'profilePic',
      'image',
      'profilePhoto',
      'profileImageUrl',
    ];

    for (final key in possibleKeys) {
      final value = user[key];
      if (value != null) {
        final stringValue = value.toString().trim();
        if (stringValue.isNotEmpty) {
          return stringValue;
        }
      }
    }
    return null;
  }
}


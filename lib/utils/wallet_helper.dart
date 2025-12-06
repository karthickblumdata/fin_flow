import '../services/wallet_service.dart';
import '../services/auth_service.dart';

/// Helper utility to check if current user or specified user has a wallet
class WalletHelper {
  /// Check if current logged-in user has a wallet
  /// Uses isNonWalletUser flag for faster check (no API call needed)
  static Future<bool> currentUserHasWallet() async {
    try {
      // Check isNonWalletUser flag first (faster, no API call)
      final isNonWallet = await AuthService.isNonWalletUser();
      if (isNonWallet) {
        return false; // Non-wallet users don't have wallets
      }
      
      // For wallet users, check via API (fallback)
      return await WalletService.hasWallet();
    } catch (e) {
      return false;
    }
  }

  /// Check if a specific user has a wallet
  static Future<bool> userHasWallet(String userId) async {
    try {
      if (userId.isEmpty) return false;
      return await WalletService.hasWallet(userId: userId);
    } catch (e) {
      return false;
    }
  }

  /// Filter users list to only include users with wallets
  static Future<List<Map<String, dynamic>>> filterUsersWithWallets(
    List<Map<String, dynamic>> users,
  ) async {
    final filteredUsers = <Map<String, dynamic>>[];
    
    for (final user in users) {
      final userId = user['id']?.toString() ?? user['_id']?.toString() ?? '';
      if (userId.isNotEmpty) {
        final hasWallet = await userHasWallet(userId);
        if (hasWallet) {
          filteredUsers.add(user);
        }
      }
    }
    
    return filteredUsers;
  }

  /// Check if multiple users have wallets (batch check)
  /// Returns a map of userId -> hasWallet
  static Future<Map<String, bool>> batchCheckWallets(
    List<String> userIds,
  ) async {
    final results = <String, bool>{};
    
    for (final userId in userIds) {
      if (userId.isNotEmpty) {
        results[userId] = await userHasWallet(userId);
      }
    }
    
    return results;
  }
}


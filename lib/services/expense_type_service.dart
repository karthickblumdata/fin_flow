import 'api_service.dart';
import '../utils/api_constants.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExpenseTypeService {
  /// Get all expense types
  static Future<Map<String, dynamic>> getExpenseTypes() async {
    try {
      final response = await ApiService.get(
        ApiConstants.getExpenseTypes,
      );

      return {
        'success': true,
        'expenseTypes': response['expenseTypes'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'expenseTypes': [],
        'count': 0,
      };
    }
  }

  /// Create new expense type
  static Future<Map<String, dynamic>> createExpenseType({
    required String name,
    String? description,
    bool isActive = true,
    String? imageUrl,
    bool proofRequired = false,
  }) async {
    try {
      print('\n📝 ===== CREATE EXPENSE TYPE REQUEST (Frontend) =====');
      print('   Name: ${name.trim()}');
      print('   Description: ${description != null && description.trim().isNotEmpty ? "provided" : "not provided"}');
      print('   IsActive: $isActive');
      print('   ImageUrl: ${imageUrl != null && imageUrl.trim().isNotEmpty ? "provided" : "not provided"}');
      print('   ProofRequired: $proofRequired');
      print('====================================================\n');

      final requestData = <String, dynamic>{
        'name': name.trim(),
        'isActive': isActive,
        'proofRequired': proofRequired,
      };
      
      if (description != null && description.trim().isNotEmpty) {
        requestData['description'] = description.trim();
      }
      
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        requestData['imageUrl'] = imageUrl.trim();
      }

      print('   Sending request to: ${ApiConstants.createExpenseType}');
      print('   Request data: $requestData');

      final response = await ApiService.post(
        ApiConstants.createExpenseType,
        requestData,
      );

      print('   Response received:');
      print('   Success: ${response['success']}');
      print('   Message: ${response['message']}');
      print('   StatusCode: ${response['statusCode'] ?? "N/A"}');

      // Check if response indicates success
      if (response['success'] == true) {
        print('✅ Expense type created successfully');
        return {
          'success': true,
          'message': response['message'] ?? 'Expense type created successfully',
          'expenseType': response['expenseType'],
        };
      } else {
        // Handle error response from API
        print('❌ Failed to create expense type: ${response['message']}');
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to create expense type',
          'statusCode': response['statusCode'],
        };
      }
    } catch (e) {
      print('\n❌ ===== ERROR CREATING EXPENSE TYPE (Frontend) =====');
      print('   Error: $e');
      print('===================================================\n');
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update expense type
  static Future<Map<String, dynamic>> updateExpenseType(
    String expenseTypeId, {
    String? name,
    String? description,
    bool? isActive,
    String? imageUrl,
    bool? proofRequired,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
      if (description != null) body['description'] = description.trim();
      if (isActive != null) body['isActive'] = isActive;
      if (imageUrl != null && imageUrl.trim().isNotEmpty) body['imageUrl'] = imageUrl.trim();
      // Always send proofRequired when provided (even if false) to explicitly set the value
      // This ensures the backend always receives and saves the boolean value
      // Since _isProofRequired is always a bool (never null), this will always be sent
      if (proofRequired != null) {
        body['proofRequired'] = proofRequired;
      }

      final response = await ApiService.put(
        ApiConstants.updateExpenseType(expenseTypeId),
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense type updated successfully',
        'expenseType': response['expenseType'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete expense type
  static Future<Map<String, dynamic>> deleteExpenseType(String expenseTypeId) async {
    try {
      final response = await ApiService.delete(
        ApiConstants.deleteExpenseType(expenseTypeId),
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense type deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get active expense types (for dropdowns)
  static Future<Map<String, dynamic>> getActiveExpenseTypes() async {
    try {
      final response = await ApiService.get(
        ApiConstants.getExpenseTypes,
        queryParams: {'isActive': 'true'},
      );

      return {
        'success': true,
        'expenseTypes': response['expenseTypes'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'expenseTypes': [],
        'count': 0,
      };
    }
  }

  /// Upload image for expense type
  static Future<Map<String, dynamic>> uploadImage(
    String imagePath, {
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      final response = await ApiService.uploadFile(
        ApiConstants.uploadExpenseTypeImage,
        imagePath,
        'image',
        fileBytes: imageBytes,
        fileName: fileName ?? 'expense-type-image.jpg',
      );

      return {
        'success': true,
        'imageUrl': response['imageUrl'] ?? response['url'] ?? '',
        'message': response['message'] ?? 'Image uploaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}


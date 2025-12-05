import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import '../utils/api_constants.dart';

class ExpenseService {
  /// Upload expense proof image
  static Future<Map<String, dynamic>> uploadProofImage(XFile imageFile) async {
    try {
      Uint8List? fileBytes;
      String? fileName;
      
      // Read file bytes (works for both web and mobile)
      try {
        fileBytes = await imageFile.readAsBytes();
        fileName = imageFile.name.isNotEmpty ? imageFile.name : 'proof-image.jpg';
      } catch (e) {
        // For mobile platforms, use file path instead
        if (imageFile.path.isNotEmpty) {
          final response = await ApiService.uploadFile(
            ApiConstants.uploadExpenseProofImage,
            imageFile.path,
            'image',
            fileName: fileName ?? 'proof-image.jpg',
          );
          
          if (response['success'] == true) {
            return {
              'success': true,
              'imageUrl': response['imageUrl'],
            };
          } else {
            return {
              'success': false,
              'message': response['message'] ?? 'Failed to upload image',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Image file not found',
          };
        }
      }
      
      // Use bytes for upload
      final response = await ApiService.uploadFile(
        ApiConstants.uploadExpenseProofImage,
        imageFile.path, // Path for fallback
        'image',
        fileBytes: fileBytes,
        fileName: fileName,
      );
      
      if (response['success'] == true) {
        return {
          'success': true,
          'imageUrl': response['imageUrl'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to upload image',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
  /// Get all expenses with optional filters
  static Future<Map<String, dynamic>> getExpenses({
    String? userId,
    String? status,
    String? category,
    String? mode,
  }) async {
    try {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📤 [EXPENSE REPORT] Backend API Call Starting...');
      debugPrint('   Endpoint: ${ApiConstants.getExpenses}');
      
      final queryParams = <String, String>{};
      
      if (userId != null) queryParams['userId'] = userId;
      if (status != null) queryParams['status'] = status;
      if (category != null) queryParams['category'] = category;
      if (mode != null) queryParams['mode'] = mode;

      debugPrint('   Query Parameters:');
      if (queryParams.isEmpty) {
        debugPrint('      (none - fetching all expenses)');
      } else {
        queryParams.forEach((key, value) {
          debugPrint('      $key: $value');
        });
      }
      
      final queryString = queryParams.isNotEmpty ? '?' + queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&') : '';
      debugPrint('   Full URL: [BASE_URL]${ApiConstants.getExpenses}$queryString');
      debugPrint('   Making API request...');

      final response = await ApiService.get(
        ApiConstants.getExpenses,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      debugPrint('   ✅ API Response Received');
      debugPrint('   Response Status: ${response['success'] == true ? 'SUCCESS' : 'FAILED'}');
      
      if (response['success'] == true) {
        final expenses = response['expenses'] ?? [];
        final count = response['count'] ?? 0;
        debugPrint('   Expenses Count: $count');
        debugPrint('   Expenses Array Length: ${expenses is List ? expenses.length : 0}');
        
        if (expenses is List && expenses.isNotEmpty) {
          debugPrint('   Sample Expense (first item):');
          final firstExpense = expenses[0];
          if (firstExpense is Map) {
            debugPrint('      _id: ${firstExpense['_id'] ?? 'N/A'}');
            debugPrint('      amount: ${firstExpense['amount'] ?? 'N/A'}');
            debugPrint('      category: ${firstExpense['category'] ?? 'N/A'}');
            debugPrint('      status: ${firstExpense['status'] ?? 'N/A'}');
            debugPrint('      mode: ${firstExpense['mode'] ?? 'N/A'}');
            debugPrint('      date: ${firstExpense['date'] ?? firstExpense['createdAt'] ?? 'N/A'}');
          }
        } else {
          debugPrint('   ⚠️  No expenses found in response');
        }
      } else {
        debugPrint('   ❌ API Error: ${response['message'] ?? response['error'] ?? 'Unknown error'}');
        debugPrint('   Status Code: ${response['statusCode'] ?? 'N/A'}');
      }
      
      debugPrint('═══════════════════════════════════════════════════════════');

      return {
        'success': true,
        'expenses': response['expenses'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('❌ [EXPENSE REPORT] API Call Exception:');
      debugPrint('   Error: $e');
      debugPrint('═══════════════════════════════════════════════════════════');
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'expenses': [],
        'count': 0,
      };
    }
  }

  /// Create new expense
  static Future<Map<String, dynamic>> createExpense({
    String? userId, // Optional: Admin/SuperAdmin can specify userId for other users
    required String category,
    required double amount,
    required String mode,
    String? description, // Optional: Description can be empty for Super Admin
    String? proofUrl, // Optional: Proof image can be empty
  }) async {
    try {
      // Validate required fields
      if (category.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Category is required',
        };
      }
      
      if (amount <= 0 || amount.isNaN || amount.isInfinite) {
        return {
          'success': false,
          'message': 'Amount must be a valid positive number',
        };
      }
      
      if (mode.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Payment mode is required',
        };
      }
      
      final requestData = <String, dynamic>{
        'category': category.trim(),
        'amount': amount,
        'mode': mode.trim(),
      };
      
      // Handle description based on whether it's provided
      // Backend validation: SuperAdmin can have empty description, others cannot
      // Always send description field (even if empty) so backend can validate based on role
      // Backend expects description field to be present (even if empty for SuperAdmin)
      if (description != null && description.trim().isNotEmpty) {
        requestData['description'] = description.trim();
      } else {
        // Send empty string - backend will validate based on user role
        // If user is SuperAdmin, empty string is allowed
        // If user is not SuperAdmin, backend will return 400
        requestData['description'] = '';
      }
      
      // Add proofUrl only if provided (not empty), otherwise omit it
      if (proofUrl != null && proofUrl.trim().isNotEmpty) {
        requestData['proofUrl'] = proofUrl.trim();
      }
      // Note: Not sending proofUrl at all if it's empty (backend expects null or undefined for optional fields)
      
      // Add userId if provided (for Admin/SuperAdmin creating expenses for others)
      if (userId != null && userId.trim().isNotEmpty) {
        requestData['userId'] = userId.trim();
      }

      // Log request data for debugging (in development only)
      print('📤 Creating expense with data: category=${requestData['category']}, amount=${requestData['amount']}, mode=${requestData['mode']}, description=${requestData['description']?.toString().length ?? 0} chars');
      
      final response = await ApiService.post(ApiConstants.createExpense, requestData);
      
      // Check if the response indicates an error
      if (response['success'] == false || response['statusCode'] != null && response['statusCode'] >= 400) {
        final errorMessage = response['message'] ?? 'Failed to create expense';
        print('❌ Expense creation failed: $errorMessage');
        return {
          'success': false,
          'message': errorMessage,
        };
      }

      return {
        'success': true,
        'message': response['message'] ?? 'Expense created successfully',
        'expense': response['expense'],
      };
    } catch (e) {
      print('❌ Exception creating expense: $e');
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Approve expense
  /// If fromAllWalletReport is true, allows approval regardless of status
  static Future<Map<String, dynamic>> approveExpense(String expenseId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.expenseApprove(expenseId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        fromAllWalletReport ? {'fromAllWalletReport': true} : {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense approved successfully',
        'expense': response['expense'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Reject expense
  /// If fromAllWalletReport is true, allows rejection regardless of status
  static Future<Map<String, dynamic>> rejectExpense(
      String expenseId, String? reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{};
      if (reason != null) {
        requestData['reason'] = reason;
      }
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.expenseReject(expenseId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Edit expense (Pending / Rejected / Flagged)
  /// Update expense
  /// If fromAllWalletReport is true, allows editing even when status is Approved
  static Future<Map<String, dynamic>> updateExpense(
    String expenseId, {
    String? category,
    double? amount,
    String? mode,
    String? description,
    String? proofUrl,
    bool fromAllWalletReport = false,
  }) async {
    try {
      // Validate expenseId
      if (expenseId.isEmpty || expenseId.trim().isEmpty || expenseId == 'null' || expenseId == 'undefined') {
        return {
          'success': false,
          'message': 'Invalid expense ID. Cannot update expense without a valid ID.',
        };
      }

      final body = <String, dynamic>{};
      if (category != null) body['category'] = category;
      if (amount != null) body['amount'] = amount;
      if (mode != null) body['mode'] = mode;
      if (description != null) body['description'] = description;
      if (proofUrl != null) body['proofUrl'] = proofUrl;
      if (fromAllWalletReport) body['fromAllWalletReport'] = true;

      String url = ApiConstants.expenseEdit(expenseId.trim());
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }

      final response = await ApiService.put(
        url,
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense updated successfully',
        'expense': response['expense'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update expense status (e.g., mark as Unapproved)
  /// If fromAllWalletReport is true, allows status update regardless of current status
  static Future<Map<String, dynamic>> updateExpenseStatus(
      String expenseId, String status, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{'status': status};
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.expenseEdit(expenseId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.patch(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense status updated successfully',
        'expense': response['expense'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Flag expense
  /// If fromAllWalletReport is true, allows flagging regardless of status
  static Future<Map<String, dynamic>> flagExpense(
      String expenseId, String reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{'flagReason': reason};
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.expenseFlag(expenseId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense flagged successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Resubmit flagged expense
  static Future<Map<String, dynamic>> resubmitExpense(
      String expenseId, String response) async {
    try {
      final apiResponse = await ApiService.post(
        ApiConstants.expenseResubmit(expenseId),
        {'response': response},
      );

      // Check if API response indicates success
      final isSuccess = apiResponse['success'] == true;
      
      return {
        'success': isSuccess,
        'message': apiResponse['message'] ?? (isSuccess ? 'Expense resubmitted successfully' : 'Failed to resubmit expense'),
        'expense': apiResponse['expense'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete expense
  /// Delete expense
  /// If fromAllWalletReport is true, allows deletion even when status is Approved
  static Future<Map<String, dynamic>> deleteExpense(String expenseId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.expenseEdit(expenseId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.delete(
        url,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Expense deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}


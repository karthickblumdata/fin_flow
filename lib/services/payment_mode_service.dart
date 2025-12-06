import 'api_service.dart';
import '../utils/api_constants.dart';

class PaymentModeService {
  /// Get all payment modes
  /// [displayType] - Filter by display type: 'Collection', 'Expenses', or 'Transaction'
  static Future<Map<String, dynamic>> getPaymentModes({String? displayType}) async {
    try {
      // Debug logging
      print('🔍 [PaymentModeService] getPaymentModes called with displayType: $displayType');
      
      // Map frontend display types to backend values
      String? backendDisplayType;
      if (displayType != null && displayType.isNotEmpty) {
        backendDisplayType = displayType;
        if (displayType == 'Expense') {
          backendDisplayType = 'Expenses'; // Backend uses 'Expenses'
        }
      }
      
      // Use queryParams parameter instead of manually appending to URL
      final Map<String, String>? queryParams = backendDisplayType != null
          ? {'displayType': backendDisplayType}
          : null;
      
      print('🔍 [PaymentModeService] Query params: $queryParams');
      print('🔍 [PaymentModeService] Backend display type: $backendDisplayType');
      
      final response = await ApiService.get(
        ApiConstants.getPaymentModes,
        queryParams: queryParams,
      );
      
      print('🔍 [PaymentModeService] Response received: ${response['success']}, count: ${response['paymentModes']?.length ?? 0}');

      if (response['success'] == true) {
        return {
          'success': true,
          'paymentModes': response['paymentModes'] ?? [],
        };
      } else {
        // Error response from backend
        final statusCode = response['statusCode'] ?? 'Unknown';
        final message = response['message'] ?? 'Failed to fetch payment modes';
        
        return {
          'success': false,
          'message': 'Error $statusCode: $message',
          'paymentModes': [],
          'statusCode': statusCode,
          'error': message,
        };
      }
    } catch (e) {
      // Extract error message more clearly
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'paymentModes': [],
        'error': errorMessage,
      };
    }
  }

  /// Create new payment mode
  static Future<Map<String, dynamic>> createPaymentMode({
    required String modeName,
    String? description,
    bool autoPay = false,
    String? assignedReceiver,
    bool isActive = true,
    // Additional fields for UI
    String? mode, // Cash/UPI/Bank
    List<String>? display, // Collection/Transaction
    String? upiId,
  }) async {
    try {
      final body = <String, dynamic>{
        'modeName': modeName,
        'autoPay': autoPay,
        'isActive': isActive,
      };

      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      
      // Only include assignedReceiver if autoPay is true and receiver is provided
      // Backend only requires assignedReceiver when autoPay is true
      if (autoPay) {
        if (assignedReceiver != null && assignedReceiver.isNotEmpty) {
          body['assignedReceiver'] = assignedReceiver;
        }
        // If autoPay is true but no receiver, backend validation will catch it
      }
      // If autoPay is false, don't send assignedReceiver at all

      // Send display array directly to backend (new field)
      if (display != null && display.isNotEmpty) {
        // Map frontend display types to backend values
        List<String> backendDisplay = display.map((d) {
          if (d == 'Expense') return 'Expenses'; // Backend uses 'Expenses'
          return d;
        }).toList();
        body['display'] = backendDisplay;
      }

      // Store additional UI fields (mode, upiId) in description for backward compatibility
      if (mode != null || upiId != null) {
        final additionalInfo = <String>[];
        if (mode != null) additionalInfo.add('mode:$mode');
        if (upiId != null && upiId.isNotEmpty) {
          additionalInfo.add('upiId:$upiId');
        }
        
        if (body.containsKey('description') && body['description'].isNotEmpty) {
          body['description'] = '${body['description']}|${additionalInfo.join('|')}';
        } else if (additionalInfo.isNotEmpty) {
          body['description'] = additionalInfo.join('|');
        }
      }

      final response = await ApiService.post(
        ApiConstants.createPaymentMode,
        body,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Payment mode created successfully',
          'paymentMode': response['paymentMode'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to create payment mode',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update payment mode
  static Future<Map<String, dynamic>> updatePaymentMode(
    String paymentModeId, {
    String? modeName,
    String? description,
    bool? autoPay,
    String? assignedReceiver,
    bool? isActive,
    // Additional fields for UI
    String? mode,
    List<String>? display,
    String? upiId,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (modeName != null) body['modeName'] = modeName;
      if (autoPay != null) body['autoPay'] = autoPay;
      if (isActive != null) body['isActive'] = isActive;
      if (assignedReceiver != null) {
        body['assignedReceiver'] = assignedReceiver.isEmpty ? null : assignedReceiver;
      }

      // Send display array directly to backend (new field)
      if (display != null && display.isNotEmpty) {
        // Map frontend display types to backend values
        List<String> backendDisplay = display.map((d) {
          if (d == 'Expense') return 'Expenses'; // Backend uses 'Expenses'
          return d;
        }).toList();
        body['display'] = backendDisplay;
      }

      // Handle description and additional fields (mode, upiId) for backward compatibility
      if (description != null || mode != null || upiId != null) {
        final additionalInfo = <String>[];
        if (mode != null) additionalInfo.add('mode:$mode');
        if (upiId != null && upiId.isNotEmpty) {
          additionalInfo.add('upiId:$upiId');
        }
        
        if (description != null && description.isNotEmpty) {
          if (additionalInfo.isNotEmpty) {
            body['description'] = '$description|${additionalInfo.join('|')}';
          } else {
            body['description'] = description;
          }
        } else if (additionalInfo.isNotEmpty) {
          body['description'] = additionalInfo.join('|');
        }
      }

      final response = await ApiService.put(
        ApiConstants.paymentModeUpdate(paymentModeId),
        body,
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Payment mode updated successfully',
          'paymentMode': response['paymentMode'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to update payment mode',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete payment mode (soft delete - sets isActive to false)
  static Future<Map<String, dynamic>> deletePaymentMode(String paymentModeId) async {
    try {
      final response = await ApiService.delete(
        ApiConstants.paymentModeDelete(paymentModeId),
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Payment mode deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to delete payment mode',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Parse description to extract additional fields
  static Map<String, dynamic> parseDescription(String? description) {
    final result = <String, dynamic>{
      'description': '',
      'mode': null,
      'display': <String>[],
      'upiId': null,
    };

    if (description == null || description.isEmpty) {
      return result;
    }

    // Split by | to separate description from metadata
    final parts = description.split('|');
    final descriptionParts = <String>[];
    final metadata = <String, String>{};

    for (final part in parts) {
      if (part.contains(':')) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          metadata[keyValue[0]] = keyValue[1];
        }
      } else {
        descriptionParts.add(part);
      }
    }

    result['description'] = descriptionParts.join('|');
    result['mode'] = metadata['mode'];
    result['upiId'] = metadata['upiId'];
    // Parse display from description for backward compatibility (old data)
    if (metadata.containsKey('display')) {
      result['display'] = metadata['display']!.split(',').where((e) => e.isNotEmpty).toList();
    }

    return result;
  }
  
  /// Extract display field from payment mode (prefer direct field, fallback to description parsing)
  static List<String> getDisplayFromPaymentMode(Map<String, dynamic> paymentMode) {
    // First check if display field exists directly (new format)
    if (paymentMode.containsKey('display') && paymentMode['display'] is List) {
      final displayList = paymentMode['display'] as List;
      return displayList.map((e) => e.toString()).toList();
    }
    
    // Fallback: parse from description (old format)
    final description = paymentMode['description']?.toString();
    if (description != null && description.isNotEmpty) {
      final parsed = parseDescription(description);
      if (parsed['display'] is List && (parsed['display'] as List).isNotEmpty) {
        return (parsed['display'] as List).map((e) => e.toString()).toList();
      }
    }
    
    // Default: return Collection
    return ['Collection'];
  }
}

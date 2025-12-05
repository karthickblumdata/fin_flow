import 'api_service.dart';
import '../utils/api_constants.dart';

class CollectionService {
  /// Get all collections with optional filters
  static Future<Map<String, dynamic>> getCollections({
    String? collectedBy,
    String? assignedReceiver,
    String? status,
    String? mode,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (collectedBy != null) queryParams['collectedBy'] = collectedBy;
      if (assignedReceiver != null) queryParams['assignedReceiver'] = assignedReceiver;
      if (status != null) queryParams['status'] = status;
      if (mode != null) queryParams['mode'] = mode;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await ApiService.get(
        ApiConstants.getCollections,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': true,
        'collections': response['collections'] ?? [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'collections': [],
      };
    }
  }

  /// Create new collection (Staff only)
  static Future<Map<String, dynamic>> createCollection({
    required String customerName,
    required double amount,
    required String mode,
    String? paymentModeId,
    String? assignedReceiver,
    String? proofUrl,
    String? notes,
  }) async {
    try {
      final response = await ApiService.post(ApiConstants.createCollection, {
        'customerName': customerName,
        'amount': amount,
        'mode': mode,
        if (paymentModeId != null) 'paymentModeId': paymentModeId,
        if (assignedReceiver != null) 'assignedReceiver': assignedReceiver,
        if (proofUrl != null) 'proofUrl': proofUrl,
        if (notes != null) 'notes': notes,
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Collection created successfully',
        'collection': response['collection'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Approve collection
  /// If fromAllWalletReport is true, allows approval regardless of status
  static Future<Map<String, dynamic>> approveCollection(String collectionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.collectionApprove(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        fromAllWalletReport ? {'fromAllWalletReport': true} : {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection approved successfully',
        'collection': response['collection'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Reject collection
  /// If fromAllWalletReport is true, allows rejection regardless of status
  static Future<Map<String, dynamic>> rejectCollection(
      String collectionId, String? reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{};
      if (reason != null) {
        requestData['reason'] = reason;
      }
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.collectionReject(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Flag collection
  /// If fromAllWalletReport is true, allows flagging regardless of status
  static Future<Map<String, dynamic>> flagCollection(
      String collectionId, String reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{'flagReason': reason};
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.collectionFlag(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection flagged successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Resubmit flagged collection
  static Future<Map<String, dynamic>> resubmitCollection(
      String collectionId, String response) async {
    try {
      final apiResponse = await ApiService.post(
        ApiConstants.collectionResubmit(collectionId),
        {'response': response},
      );

      return {
        'success': true,
        'message': apiResponse['message'] ?? 'Collection resubmitted successfully',
        'collection': apiResponse['collection'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Edit collection
  /// Edit collection
  /// If fromAllWalletReport is true, allows editing even when status is Approved
  static Future<Map<String, dynamic>> editCollection(
    String collectionId, {
    String? customerName,
    double? amount,
    String? mode,
    String? paymentModeId,
    String? proofUrl,
    String? notes,
    bool fromAllWalletReport = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (customerName != null) body['customerName'] = customerName;
      if (amount != null) body['amount'] = amount;
      if (mode != null) body['mode'] = mode;
      if (paymentModeId != null) body['paymentModeId'] = paymentModeId;
      if (proofUrl != null) body['proofUrl'] = proofUrl;
      if (notes != null) body['notes'] = notes;
      if (fromAllWalletReport) body['fromAllWalletReport'] = true;

      String url = ApiConstants.collectionEdit(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }

      final response = await ApiService.put(
        url,
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection updated successfully',
        'collection': response['collection'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Restore rejected collection
  /// Restore collection (unapprove)
  /// If fromAllWalletReport is true, allows restoring regardless of status
  static Future<Map<String, dynamic>> restoreCollection(String collectionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.collectionRestore(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        fromAllWalletReport ? {'fromAllWalletReport': true} : {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection restored successfully',
        'collection': response['collection'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete collection
  /// Delete collection
  /// If fromAllWalletReport is true, allows deletion even when status is Approved
  static Future<Map<String, dynamic>> deleteCollection(String collectionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.collectionEdit(collectionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.delete(
        url,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Collection deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}

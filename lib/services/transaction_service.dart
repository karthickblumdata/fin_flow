import 'api_service.dart';
import '../utils/api_constants.dart';

class TransactionService {
  /// Get all transactions with optional filters
  static Future<Map<String, dynamic>> getTransactions({
    String? sender,
    String? receiver,
    String? status,
    String? mode,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (sender != null) queryParams['sender'] = sender;
      if (receiver != null) queryParams['receiver'] = receiver;
      if (status != null) queryParams['status'] = status;
      if (mode != null) queryParams['mode'] = mode;

      final response = await ApiService.get(
        ApiConstants.getTransactions,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': true,
        'transactions': response['transactions'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'transactions': [],
        'count': 0,
      };
    }
  }

  /// Create new transaction
  static Future<Map<String, dynamic>> createTransaction({
    required String sender,
    required String receiver,
    required double amount,
    required String mode,
    String? purpose,
    String? proofUrl,
  }) async {
    try {
      final response = await ApiService.post(ApiConstants.createTransaction, {
        'sender': sender,
        'receiver': receiver,
        'amount': amount,
        'mode': mode,
        if (purpose != null) 'purpose': purpose,
        if (proofUrl != null) 'proofUrl': proofUrl,
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction created successfully',
        'transaction': response['transaction'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Approve transaction
  /// If fromAllWalletReport is true, allows approval regardless of status
  static Future<Map<String, dynamic>> approveTransaction(String transactionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.transactionApprove(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        fromAllWalletReport ? {'fromAllWalletReport': true} : {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction approved successfully',
        'transaction': response['transaction'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Reject transaction
  /// If fromAllWalletReport is true, allows rejection regardless of status
  static Future<Map<String, dynamic>> rejectTransaction(
      String transactionId, String? reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{};
      if (reason != null) {
        requestData['reason'] = reason;
      }
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.transactionReject(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Cancel transaction (unapprove)
  /// If fromAllWalletReport is true, allows canceling regardless of status
  static Future<Map<String, dynamic>> cancelTransaction(String transactionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.transactionCancel(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        fromAllWalletReport ? {'fromAllWalletReport': true} : {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction cancelled successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Flag transaction
  /// If fromAllWalletReport is true, allows flagging regardless of status
  static Future<Map<String, dynamic>> flagTransaction(
      String transactionId, String reason, {bool fromAllWalletReport = false}) async {
    try {
      final requestData = <String, dynamic>{'flagReason': reason};
      if (fromAllWalletReport) {
        requestData['fromAllWalletReport'] = true;
      }
      String url = ApiConstants.transactionFlag(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.post(
        url,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction flagged successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Resubmit flagged transaction
  static Future<Map<String, dynamic>> resubmitTransaction(
      String transactionId, String response) async {
    print('\n🚩 ===== TRANSACTION RESUBMIT API CALL =====');
    print('🚩 [RESUBMIT API] Transaction ID: $transactionId');
    print('🚩 [RESUBMIT API] Response text: $response');
    print('🚩 [RESUBMIT API] API Endpoint: ${ApiConstants.transactionResubmit(transactionId)}');
    print('🚩 [RESUBMIT API] Request body: {response: $response}');
    print('==========================================\n');
    
    try {
      print('🚩 [RESUBMIT API] Making POST request...');
      final apiResponse = await ApiService.post(
        ApiConstants.transactionResubmit(transactionId),
        {'response': response},
      );

      print('🚩 [RESUBMIT API] ✅ API Response received:');
      print('   success: ${apiResponse['success']}');
      print('   message: ${apiResponse['message']}');
      print('   transaction: ${apiResponse['transaction'] != null ? 'Present' : 'Missing'}');
      
      if (apiResponse['transaction'] != null) {
        final transaction = apiResponse['transaction'];
        print('   transaction._id: ${transaction['_id']}');
        print('   transaction.status: ${transaction['status']}');
        print('   transaction.response: ${transaction['response']}');
      }

      final result = {
        'success': true,
        'message': apiResponse['message'] ?? 'Transaction resubmitted successfully',
        'transaction': apiResponse['transaction'],
      };
      
      print('🚩 [RESUBMIT API] ✅ Returning success result');
      print('==========================================\n');
      return result;
    } catch (e) {
      print('🚩 [RESUBMIT API] ❌ ERROR occurred:');
      print('   Error type: ${e.runtimeType}');
      print('   Error message: ${e.toString()}');
      print('==========================================\n');
      
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Edit transaction (Pending / Flagged / Rejected / Cancelled)
  /// If fromAllWalletReport is true, allows editing even when status is Approved/Completed
  static Future<Map<String, dynamic>> editTransaction(
    String transactionId, {
    double? amount,
    String? mode,
    String? purpose,
    String? proofUrl,
    bool fromAllWalletReport = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (amount != null) body['amount'] = amount;
      if (mode != null) body['mode'] = mode;
      if (purpose != null) body['purpose'] = purpose;
      if (proofUrl != null) body['proofUrl'] = proofUrl;
      if (fromAllWalletReport) body['fromAllWalletReport'] = true;

      String url = ApiConstants.transactionEdit(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }

      final response = await ApiService.put(
        url,
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction updated successfully',
        'transaction': response['transaction'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete transaction
  /// Delete transaction
  /// If fromAllWalletReport is true, allows deletion even when status is Approved/Completed
  static Future<Map<String, dynamic>> deleteTransaction(String transactionId, {bool fromAllWalletReport = false}) async {
    try {
      String url = ApiConstants.transactionEdit(transactionId);
      if (fromAllWalletReport) {
        url += '?fromAllWalletReport=true';
      }
      final response = await ApiService.delete(
        url,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Transaction deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}


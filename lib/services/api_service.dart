import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class ApiService {
  static const String _tokenKey = 'auth_token';
  
  // Get authorization header with token
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (includeAuth) {
      final token = await _getStoredToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      // Don't log warning here - it will be handled by the request methods
      // that check for token before making the request
    }
    
    return headers;
  }
  
  // Get stored token from SharedPreferences
  static Future<String?> _getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }
  
  // Save token to SharedPreferences
  static Future<void> setToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(_tokenKey, token);
      } else {
        await prefs.remove(_tokenKey);
      }
    } catch (e) {
      // Handle error
    }
  }
  
  // Get token (public method)
  static Future<String?> getToken() => _getStoredToken();
  
  // Clear token
  static Future<void> clearToken() async {
    await setToken(null);
  }
  
  // GET request
  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams, bool includeAuth = true}) async {
    try {
      // Check if token is available for authenticated requests (early check)
      if (includeAuth) {
        final token = await _getStoredToken();
        if (token == null || token.isEmpty) {
          // Return a specific error instead of making the request
          return {
            'success': false,
            'message': 'Authentication required. Please login again.',
            'error': 'NO_TOKEN',
            'statusCode': 401
          };
        }
      }
      
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      Uri uri = Uri.parse(fullUrl);
      
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
        print('🔍 [ApiService.get] Added query params: $queryParams');
        print('🔍 [ApiService.get] Final URI: ${uri.toString()}');
      } else {
        print('🔍 [ApiService.get] No query params provided');
        print('🔍 [ApiService.get] Final URI: ${uri.toString()}');
      }
      
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.get(uri, headers: headers);
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to connect to $fullUrl. Error: $e');
    }
  }
  
  // POST request
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool includeAuth = true}) async {
    try {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      final uri = Uri.parse(fullUrl);
      // Check if token is available for authenticated requests (early check)
      if (includeAuth) {
        final token = await _getStoredToken();
        if (token == null || token.isEmpty) {
          // Return a specific error instead of making the request
          return {
            'success': false,
            'message': 'Authentication required. Please login again.',
            'error': 'NO_TOKEN',
            'statusCode': 401
          };
        }
      }
      
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to connect to $fullUrl. Error: $e');
    }
  }
  
  // PUT request
  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      final uri = Uri.parse(fullUrl);
      final headers = await _getHeaders();
      
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to connect to $fullUrl. Error: $e');
    }
  }
  
  // DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      final uri = Uri.parse(fullUrl);
      final headers = await _getHeaders();
      
      final response = await http.delete(uri, headers: headers);
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to connect to $fullUrl. Error: $e');
    }
  }
  
  // PATCH request
  static Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      final uri = Uri.parse(fullUrl);
      final headers = await _getHeaders();
      
      final response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to connect to $fullUrl. Error: $e');
    }
  }

  // Multipart file upload
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String filePath,
    String fieldName, {
    Map<String, String>? additionalFields,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      final uri = Uri.parse(fullUrl);
      final token = await _getStoredToken();
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization header
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add file - handle web (bytes) vs mobile/desktop (file path)
      if (fileBytes != null) {
        // For web platform, use bytes
        final file = http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: fileName ?? 'image.jpg',
        );
        request.files.add(file);
      } else {
        // For mobile/desktop, use file path
        final file = await http.MultipartFile.fromPath(fieldName, filePath);
        request.files.add(file);
      }
      
      // Add additional fields if provided
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } catch (e) {
      final fullUrl = '${ApiConstants.baseUrl}$endpoint';
      throw Exception('Failed to upload file to $fullUrl. Error: $e');
    }
  }
  
  // Handle response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    // Handle empty response body
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {'success': true, 'message': 'Operation completed successfully'};
      } else {
        return {
          'success': false,
          'statusCode': statusCode,
          'message': 'An error occurred: $statusCode (No response body)'
        };
      }
    }
    
    try {
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Handle 401 Unauthorized - token expired or invalid
      if (statusCode == 401) {
        // Clear token and throw error
        clearToken();
        throw Exception(responseBody['message'] ?? 'Authentication failed. Please login again.');
      }
      
      // Handle 403 Forbidden - permission denied
      // Log the error for debugging
      if (statusCode == 403) {
        final message = responseBody['message']?.toString() ?? '';
        print('\n🚫 ===== PERMISSION DENIED ERROR =====');
        print('   Status: 403 Forbidden');
        print('   Message: $message');
        print('   Suggestion: User may need to refresh permissions or log out/in');
        print('=====================================\n');
      }
      
      if (statusCode >= 200 && statusCode < 300) {
        return responseBody;
      } else {
        // Return error response instead of throwing for non-401 errors
        // This allows the caller to handle the error message properly
        return {
          'success': false,
          'statusCode': statusCode,
          'message': responseBody['message'] ?? 'An error occurred: $statusCode',
          ...responseBody, // Include any additional error details
        };
      }
    } catch (e) {
      if (e is Exception && statusCode != 401) {
        // For parsing errors, still return the status code info
        return {
          'success': false,
          'statusCode': statusCode,
          'message': 'Invalid response format: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}'
        };
      }
      // Re-throw 401 exceptions as they need special handling
      throw e;
    }
  }
}

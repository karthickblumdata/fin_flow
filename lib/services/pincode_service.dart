import 'dart:convert';
import 'package:http/http.dart' as http;

class PincodeService {
  // Free India Postal API
  static const String _baseUrl = 'https://api.postalpincode.in/pincode';

  /// Get state and district from pincode
  /// Returns: {'success': true, 'state': 'State Name', 'district': 'District Name'} or {'success': false, 'message': 'Error'}
  static Future<Map<String, dynamic>> getStateFromPincode(String pincode) async {
    if (pincode.isEmpty || pincode.length != 6) {
      return {
        'success': false,
        'message': 'Please enter a valid 6-digit PIN code',
      };
    }

    try {
      final url = Uri.parse('$_baseUrl/$pincode');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List<dynamic>?;
          
          if (postOffices != null && postOffices.isNotEmpty) {
            final firstOffice = postOffices[0] as Map<String, dynamic>;
            final state = firstOffice['State']?.toString().trim() ?? '';
            final district = firstOffice['District']?.toString().trim() ?? '';
            
            if (state.isNotEmpty) {
              return {
                'success': true,
                'state': state,
                'district': district,
              };
            }
          }
        }
        
        return {
          'success': false,
          'message': 'PIN code not found',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch PIN code details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}


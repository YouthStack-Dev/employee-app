import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class AlertService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> triggerSOSAlert({int? bookingId, String notes = ''}) async {
    try {
      // 1. Check/Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'success': false, 'error': 'Location permission denied'};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {'success': false, 'error': 'Location permissions are permanently denied'};
      }

      // 2. Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Get Auth data
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tenantId = prefs.getString('tenant_id');

      if (token == null) {
        return {'success': false, 'error': 'Not logged in'};
      }

      // 4. Prepare Payload
      final payload = {
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'booking_id': bookingId,
        'alert_type': 'SOS',
        'severity': 'CRITICAL',
        'trigger_notes': notes,
        'evidence_urls': []
      };

      // 5. POST to Backend
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/v1/alerts/trigger',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            if (tenantId != null) 'X-Tenant-Id': tenantId,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Alert failed';
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) {
           final detail = data['detail'];
           if (detail is Map && detail.containsKey('message')) {
             errorMessage = detail['message'];
           } else {
             errorMessage = detail.toString();
           }
        } else if (data is Map && data.containsKey('message')) {
           errorMessage = data['message'];
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }
  Future<Map<String, dynamic>> fetchMyAlerts({
    int limit = 20, 
    int offset = 0,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tenantId = prefs.getString('tenant_id');

      if (token == null) {
        return {'success': false, 'error': 'Not logged in'};
      }

      final Map<String, dynamic> queryParams = {
        'limit': limit,
        'offset': offset,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.myAlerts}',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            if (tenantId != null) 'X-Tenant-Id': tenantId,
          },
        ),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'Failed to fetch alerts'};
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to load alerts';
      if (e.response != null && e.response?.data != null) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
              errorMessage = data['message'];
          }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

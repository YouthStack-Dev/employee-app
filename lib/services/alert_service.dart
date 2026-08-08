import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

class AlertService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> triggerSOSAlert({int? bookingId, String notes = ''}) async {
    try {
      // 1. Check/Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'success': false, 'error': 'Location permission is required to send an SOS alert. Please allow location access.'};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {'success': false, 'error': 'Location permissions are permanently denied. Please enable them in your phone Settings to use SOS.'};
      }

      // 2. Get current position
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        // If location fails, still try to send SOS without coordinates
        position = Position(
          latitude: 0, longitude: 0, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, altitudeAccuracy: 0,
          heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
        );
      }

      // 3. Prepare Payload
      final payload = {
        'current_latitude': position.latitude != 0 ? position.latitude : null,
        'current_longitude': position.longitude != 0 ? position.longitude : null,
        'booking_id': bookingId,
        'alert_type': 'SOS',
        'severity': 'CRITICAL',
        'trigger_notes': notes,
        'evidence_urls': []
      };

      // 4. POST to Backend
      final response = await _apiService.dio.post(
        ApiConstants.triggerAlert,
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'SOS alert could not be sent. Please try again or call emergency services directly.'};
      }
    } on DioException catch (e) {
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': 'No internet connection. Your SOS could not be sent. Please call emergency services directly.'};
      }
      return {'success': false, 'error': _parseError(e, 'SOS alert failed. Please try again.')};
    } catch (e) {
      return {'success': false, 'error': 'SOS alert failed. Please try again or call emergency services.'};
    }
  }

  Future<Map<String, dynamic>> fetchMyAlerts({
    int limit = 20, 
    int offset = 0,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'limit': limit,
        'offset': offset,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (status != null) queryParams['status'] = status;

      final response = await _apiService.dio.get(
        ApiConstants.myAlerts,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'Unable to load your alert history.'};
      }
    } on DioException catch (e) {
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': ApiError.getUserMessage(e)};
      }
      return {'success': false, 'error': _parseError(e, 'Failed to load alerts. Please try again.')};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> fetchAlertDetails(int alertId) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConstants.alerts}/$alertId',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      } else {
        return {'success': false, 'error': 'Unable to load alert details.'};
      }
    } on DioException catch (e) {
      if (ApiError.isNetworkError(e)) {
        return {'success': false, 'error': ApiError.getUserMessage(e)};
      }
      return {'success': false, 'error': _parseError(e, 'Failed to load alert details.')};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  String _parseError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['message'] != null) return detail['message'].toString();
      if (detail is String && detail.isNotEmpty) return detail;
      if (data['message'] is String) return data['message'];
    }
    return fallback;
  }
}

import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/nodal_models.dart';
import 'api_service.dart';

class NodalService {
  final ApiService _apiService = ApiService();

  /// GET /api/v1/employee/nodal/assignment
  Future<Map<String, dynamic>> getAssignment() async {
    try {
      final response = await _apiService.dio.get(ApiConstants.nodalAssignment);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {'success': true, 'data': NodalPoint.fromJson(data)};
        }
        if (data is Map) {
          return {'success': true, 'data': NodalPoint.fromJson(Map<String, dynamic>.from(data))};
        }
      }
      return {'success': false, 'error': 'Failed to fetch nodal assignment'};
    } on DioException catch (e) {
      return {'success': false, 'error': _friendly(e), 'code': e.response?.statusCode};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// POST /api/v1/employee/nodal/scan  body {"vehicle_number": "KA01AB1234"}
  Future<Map<String, dynamic>> scan(String vehicleNumber) async {
    try {
      final response = await _apiService.dio.post(
        ApiConstants.nodalScan,
        data: {'vehicle_number': vehicleNumber},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {'success': true, 'data': NodalScanResult.fromJson(data)};
        }
        if (data is Map) {
          return {'success': true, 'data': NodalScanResult.fromJson(Map<String, dynamic>.from(data))};
        }
        return {'success': true};
      }
      return {'success': false, 'error': 'Onboarding failed'};
    } on DioException catch (e) {
      return {'success': false, 'error': _friendly(e), 'code': e.response?.statusCode, 'errorCode': _errorCode(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Extract the backend error CODE string (e.g. VEHICLE_NOT_FOUND) if present.
  String? _errorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['code'] != null) return detail['code'].toString();
      if (data['code'] != null) return data['code'].toString();
      if (data['error_code'] != null) return data['error_code'].toString();
    }
    return null;
  }

  /// Map known nodal error codes / statuses to friendly, actionable copy.
  String _friendly(DioException e) {
    if (ApiError.isNetworkError(e)) {
      return ApiError.getUserMessage(e);
    }
    final code = _errorCode(e);
    switch (code) {
      case 'VEHICLE_NOT_FOUND':
        return 'That vehicle number isn\'t recognised. Check the QR sticker and try again.';
      case 'ROUTE_NOT_FOUND':
        return 'No active trip is running for this vehicle right now.';
      case 'BOOKING_NOT_FOUND':
        return 'You don\'t have a scheduled booking on this vehicle today.';
      case 'NOT_NODAL_SHIFT':
        return 'This booking isn\'t a nodal-point shift, so QR boarding doesn\'t apply.';
      case 'BOARDING_WINDOW_CLOSED':
        return 'The boarding window has closed (more than 30 min after shift start).';
      case 'APP_ACCESS_DISABLED':
        return 'Your app access has been disabled. Please contact your transport admin.';
      case 'ACCOUNT_INACTIVE':
        return 'Your account is inactive. Please contact your transport admin.';
      case 'ASSIGNMENT_NOT_FOUND':
        return 'No nodal point has been assigned to you yet.';
    }

    // Fall back to any server-provided message, then to status-based copy.
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map && detail['message'] != null) return detail['message'].toString();
      if (data['message'] is String && (data['message'] as String).isNotEmpty) return data['message'];
    } else if (data is String && data.isNotEmpty) {
      return data;
    }

    switch (e.response?.statusCode) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You don\'t have access to nodal boarding.';
      case 404:
        return 'Nothing found for this scan.';
      case 422:
        return 'Invalid vehicle number format.';
    }
    return e.message ?? 'Network error. Please try again.';
  }
}

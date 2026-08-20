import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../models/nodal_models.dart';
import 'api_service.dart';

class NodalService {
  final ApiService _apiService = ApiService();

  /// GET /api/v1/app/employee/nodal/assignment
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

  /// POST /api/v1/app/employee/nodal/scan  body {"vehicle_number": "KA01AB1234"}
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
    return ApiError.resolve(e, feature: 'nodal', fallback: AppErrorMessages.nodalScanFailed);
  }
}

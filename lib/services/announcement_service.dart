import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../models/announcement_model.dart';
import 'api_service.dart';

class AnnouncementService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getInbox({bool unreadOnly = false, int page = 1, int pageSize = 20}) async {
    try {
      final Map<String, dynamic> queryParameters = {
        'page': page,
        'page_size': pageSize,
      };

      if (unreadOnly) {
        queryParameters['unread_only'] = 'true';
      }

      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant_id');

      final response = await _apiService.dio.get(
        ApiConstants.employeeAnnouncements,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            if (tenantId != null) 'X-Tenant-Id': tenantId,
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 404) {
        return {'success': true, 'data': <Announcement>[]};
      }

      return _parseResponse(response, (data) {
        if (data == null) return [];
        return (data as List).map((json) => Announcement.fromJson(json)).toList();
      });
    } catch (e) {
      if (e is DioException) {
        return {'success': false, 'error': ApiError.resolve(e, feature: 'announcement', fallback: AppErrorMessages.announcementLoadFailed)};
      }
      return {'success': false, 'error': AppErrorMessages.announcementLoadFailed};
    }
  }

  Future<Map<String, dynamic>> markAsRead(int announcementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant_id');

      final response = await _apiService.dio.post(
        '${ApiConstants.employeeAnnouncements}/$announcementId/read',
        data: {},
        options: Options(
          headers: {
            if (tenantId != null) 'X-Tenant-Id': tenantId,
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      return _parseResponse(response, (data) => data);
    } catch (e) {
      if (e is DioException) {
        return {'success': false, 'error': ApiError.resolve(e, feature: 'announcement', fallback: 'Could not mark as read. Please try again.')};
      }
      return {'success': false, 'error': 'Could not mark as read. Please try again.'};
    }
  }

  Map<String, dynamic> _parseResponse(Response response, dynamic Function(dynamic data)? onSuccessData) {
    try {
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        final dataVal = response.data['data'];
        return {
          'success': true,
          'data': onSuccessData != null ? onSuccessData(dataVal) : dataVal,
          'message': response.data['message'],
          'meta': response.data['meta'],
        };
      } else {
        // Handle common error structures
        String errorMsg = 'Unknown error occurred (${response.statusCode})';
        var responseData = response.data;
        if (responseData is Map<String, dynamic>) {
           errorMsg = responseData['message'] ?? responseData['error'] ?? responseData['detail'] ?? errorMsg;
        } else if (responseData is String) {
           errorMsg = responseData;
        }
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'error': 'Failed to parse API response: $e'};
    }
  }
}

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../models/shift_model.dart';
import 'api_service.dart';

class ShiftService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> fetchShifts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant_id');

      if (tenantId == null) {
        return {'success': false, 'error': 'Tenant ID not found'};
      }

      // Add query parameters as seen in RN
      final url = '${ApiConstants.shifts}/?skip=0&limit=100&is_active=true&tenant_id=$tenantId';
      
      print('Fetching shifts from: $url');
      final response = await _apiService.dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> shiftsData = [];

        // Robust parsing similar to RN
        if (data is List) {
          shiftsData = data;
        } else if (data['data'] != null) {
          final innerData = data['data'];
          if (innerData is List) {
            shiftsData = innerData;
          } else if (innerData['items'] is List) {
             shiftsData = innerData['items'];
          } else if (innerData['shifts'] is List) {
             shiftsData = innerData['shifts'];
          }
        } else if (data['shifts'] is List) {
          shiftsData = data['shifts'];
        } else if (data['items'] is List) {
          shiftsData = data['items'];
        }

        final shifts = shiftsData.map((json) => Shift.fromJson(json)).toList();
        
        final inShifts = shifts.where((s) => s.logType == 'IN').toList();
        final outShifts = shifts.where((s) => s.logType == 'OUT').toList();

        return {
          'success': true,
          'shifts': {
            'in': inShifts,
            'out': outShifts,
            'all': shifts,
          }
        };
      }
      return {'success': false, 'error': 'Failed to fetch shifts'};
    } on DioException catch (e) {
      return {'success': false, 'error': ApiError.resolve(e, feature: 'shift', fallback: AppErrorMessages.shiftLoadFailed)};
    } catch (e) {
      return {'success': false, 'error': AppErrorMessages.shiftLoadFailed};
    }
  }
}

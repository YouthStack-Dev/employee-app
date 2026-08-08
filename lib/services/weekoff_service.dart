import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import 'api_service.dart';

class WeekoffService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getWeekoffConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getString('employee_id');

      if (employeeId == null) {
        return {'success': false, 'error': 'Employee ID not found'};
      }

      final url = '${ApiConstants.weekoffConfig}/$employeeId';
      print('WEEKOFF URL: $url'); // DEBUG
      final response = await _apiService.dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null && data['data']['weekoff_config'] != null) {
          final config = data['data']['weekoff_config'];
          final List<String> weekoffDays = [];

          if (config['sunday'] == true) weekoffDays.add('SUNDAY');
          if (config['monday'] == true) weekoffDays.add('MONDAY');
          if (config['tuesday'] == true) weekoffDays.add('TUESDAY');
          if (config['wednesday'] == true) weekoffDays.add('WEDNESDAY');
          if (config['thursday'] == true) weekoffDays.add('THURSDAY');
          if (config['friday'] == true) weekoffDays.add('FRIDAY');
          if (config['saturday'] == true) weekoffDays.add('SATURDAY');

          return {'success': true, 'weekoffDays': weekoffDays};
        }
        return {'success': true, 'weekoffDays': <String>[]};
      }
      return {'success': false, 'error': 'Failed to fetch weekoff config'};
    } on DioException catch (e) {
      return {'success': false, 'error': ApiError.resolve(e, feature: 'weekoff', fallback: 'Unable to load your schedule settings. Please try again.')};
    } catch (e) {
      return {'success': false, 'error': 'Unable to load your schedule settings. Please try again.'};
    }
  }
}

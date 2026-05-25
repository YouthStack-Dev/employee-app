import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/chat_model.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService = ApiService();

  // ───────────────────────────────────────────────────────────
  // Open (or retrieve) the chat session for a booking
  // GET /api/v1/employee/chat/{booking_id}
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> openSession(int bookingId) async {
    try {
      final response = await _apiService.dio
          .get('${ApiConstants.employeeChat}/$bookingId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'data': ChatSession.fromJson(response.data['data']),
        };
      }
      return {'success': false, 'error': 'Failed to open chat session'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ───────────────────────────────────────────────────────────
  // Send a message to the driver
  // POST /api/v1/employee/chat/{booking_id}/send
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendMessage(
      int bookingId, String text) async {
    try {
      final response = await _apiService.dio.post(
        '${ApiConstants.employeeChat}/$bookingId/send',
        data: {'text': text},
      );
      if (response.statusCode == 201 && response.data['success'] == true) {
        return {
          'success': true,
          'data': ChatMessage.fromJson(response.data['data']),
          'message': response.data['message'] ?? 'Message sent',
        };
      }
      return {'success': false, 'error': 'Failed to send message'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ───────────────────────────────────────────────────────────
  // Retrieve paginated message history
  // GET /api/v1/employee/chat/{booking_id}/messages
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMessages(
    int bookingId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConstants.employeeChat}/$bookingId/messages',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final rawMessages = data['messages'] as List<dynamic>? ?? [];
        final messages =
            rawMessages.map((m) => ChatMessage.fromJson(m)).toList();
        final session = data['session'] != null
            ? ChatSession.fromJson(data['session'])
            : null;
        return {
          'success': true,
          'messages': messages,
          'session': session,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'per_page': data['per_page'] ?? limit,
        };
      }
      return {'success': false, 'error': 'Failed to load messages'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ───────────────────────────────────────────────────────────
  // Set employee's preferred language for this session
  // POST /api/v1/employee/chat/{booking_id}/language
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> setLanguage(
      int bookingId, String languageCode) async {
    try {
      final response = await _apiService.dio.post(
        '${ApiConstants.employeeChat}/$bookingId/language',
        data: {'language': languageCode},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'data': ChatSession.fromJson(response.data['data']),
        };
      }
      return {'success': false, 'error': 'Failed to set language'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ───────────────────────────────────────────────────────────
  // Get all supported translation language codes
  // GET /api/v1/chat/supported-languages  (no auth required)
  // ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSupportedLanguages() async {
    try {
      // Use a bare Dio instance — no auth header required
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response =
          await dio.get(ApiConstants.chatSupportedLanguages);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'data': SupportedLanguages.fromJson(response.data['data']),
        };
      }
      return {'success': false, 'error': 'Failed to fetch languages'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ───────────────────────────────────────────────────────────
  // Internal error parser
  // ───────────────────────────────────────────────────────────
  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data['detail'] is String) return data['detail'];
        if (data['detail'] is Map && data['detail']['message'] != null) {
          return data['detail']['message'];
        }
        if (data['message'] != null) return data['message'].toString();
      }
    }
    return e.message ?? 'Unknown network error';
  }
}

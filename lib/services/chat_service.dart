import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import '../constants/api_constants.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> openSession(int bookingId) async {
    try {
      final response = await _apiService.dio.get('${ApiConstants.employeeChat}/$bookingId');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {'success': true, 'data': ChatSession.fromJson(data)};
        }
      }
      return {'success': false, 'error': 'Failed to open chat session'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendMessage(int bookingId, String text) async {
    try {
      final response = await _apiService.dio.post(
        '${ApiConstants.employeeChat}/$bookingId/send',
        data: {'text': text},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {'success': true, 'data': ChatMessage.fromJson(data)};
        }
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to send message'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchMessages(int bookingId, {int skip = 0, int limit = 50}) async {
    try {
      final response = await _apiService.dio.get(
        '${ApiConstants.employeeChat}/$bookingId/messages',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          final rawMessages = data['messages'];
          final List<ChatMessage> messages = [];
          if (rawMessages is List) {
            for (final item in rawMessages) {
              if (item is Map<String, dynamic>) {
                messages.add(ChatMessage.fromJson(item));
              } else if (item is Map) {
                messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
              }
            }
          }
          ChatSession? session;
          final sessionData = data['session'];
          if (sessionData is Map<String, dynamic>) {
            session = ChatSession.fromJson(sessionData);
          } else if (sessionData is Map) {
            session = ChatSession.fromJson(Map<String, dynamic>.from(sessionData));
          }
          return {
            'success': true,
            'messages': messages,
            'session': session,
            'total': data['total'] ?? messages.length,
          };
        }
      }
      return {'success': false, 'error': 'Failed to fetch messages'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setLanguage(int bookingId, String language) async {
    try {
      final response = await _apiService.dio.post(
        '${ApiConstants.employeeChat}/$bookingId/language',
        data: {'language': language},
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {'success': true, 'data': ChatSession.fromJson(data)};
        }
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to update language'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchSupportedLanguages() async {
    // Public endpoint — must NOT carry an Authorization header. The shared
    // ApiService dio has an interceptor that auto-attaches Bearer tokens and
    // triggers a forced logout on 401, so a stale token here would log the
    // user out from what should be an unauthenticated read. Use a bare Dio.
    final publicDio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    try {
      final response = await publicDio.get(ApiConstants.chatSupportedLanguages);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data is Map && data['languages'] is Map) {
          final raw = data['languages'] as Map;
          final result = <String, String>{};
          raw.forEach((k, v) => result[k.toString()] = v?.toString() ?? k.toString());
          return {'success': true, 'languages': result};
        }
      }
      // Server reachable but payload malformed — surface this, don't mask it.
      return {'success': false, 'error': 'Unexpected language list payload', 'languages': _fallbackLanguages()};
    } on DioException catch (e) {
      // Network/HTTP failure — fall back to a static list so the picker still
      // works, but mark success=false so the caller can log/observe.
      return {'success': false, 'error': _parseError(e), 'languages': _fallbackLanguages()};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'languages': _fallbackLanguages()};
    }
  }

  DatabaseReference messagesRef(String firebasePath) {
    return FirebaseDatabase.instance.ref(firebasePath);
  }

  Stream<DatabaseEvent> onMessageAdded(String firebasePath) {
    return messagesRef(firebasePath).onChildAdded;
  }

  Stream<DatabaseEvent> onMessageChanged(String firebasePath) {
    return messagesRef(firebasePath).onChildChanged;
  }

  Map<String, String> _fallbackLanguages() {
    return {
      'en': 'English',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'fr': 'French',
      'de': 'German',
      'es': 'Spanish',
      'zh': 'Chinese (Simplified)',
      'ja': 'Japanese',
      'ko': 'Korean',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'it': 'Italian',
      'ta': 'Tamil',
      'te': 'Telugu',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'ur': 'Urdu',
    };
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'];
      if (data['detail'] is Map && data['detail']['message'] != null) return data['detail']['message'].toString();
      if (data['message'] is String) return data['message'];
    } else if (data is String) {
      return data;
    }
    if (e.response?.statusCode == 401) return 'Not authorized to access this chat';
    if (e.response?.statusCode == 403) return 'You do not have access to this booking chat';
    if (e.response?.statusCode == 404) return 'Booking not found';
    if (e.response?.statusCode == 422) return 'Invalid message or language';
    return e.message ?? 'Network error';
  }
}

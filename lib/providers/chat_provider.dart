import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  // ─── State ────────────────────────────────────────────────
  ChatSession? _session;
  final Map<String, ChatMessage> _messagesMap = {}; // key = ChatMessage.key
  SupportedLanguages? _supportedLanguages;

  bool _isLoadingSession = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _error;

  // ─── Getters ──────────────────────────────────────────────
  ChatSession? get session => _session;
  bool get isLoadingSession => _isLoadingSession;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get error => _error;
  SupportedLanguages? get supportedLanguages => _supportedLanguages;

  /// Sorted by time ascending
  List<ChatMessage> get messages {
    final list = _messagesMap.values.toList();
    list.sort((a, b) => a.sortTime.compareTo(b.sortTime));
    return list;
  }

  // ─── Open / retrieve session ──────────────────────────────
  Future<bool> openSession(int bookingId) async {
    _isLoadingSession = true;
    _error = null;
    notifyListeners();

    final result = await _chatService.openSession(bookingId);
    _isLoadingSession = false;

    if (result['success'] == true) {
      _session = result['data'] as ChatSession;
      notifyListeners();
      return true;
    } else {
      _error = result['error']?.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Load message history from REST API ───────────────────
  Future<void> loadMessages(int bookingId, {bool refresh = false}) async {
    if (refresh) _messagesMap.clear();

    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    final result = await _chatService.getMessages(bookingId, limit: 100);
    _isLoadingMessages = false;

    if (result['success'] == true) {
      final msgs = result['messages'] as List<ChatMessage>;
      for (final m in msgs) {
        _messagesMap[m.key] = m;
      }
      // Also refresh session from the response (has updated language prefs)
      if (result['session'] != null) {
        _session = result['session'] as ChatSession;
      }
    } else {
      _error = result['error']?.toString();
    }
    notifyListeners();
  }

  // ─── Apply a Firebase message (child added / changed) ─────
  void applyFirebaseMessage(String pushKey, Map<dynamic, dynamic> data) {
    final msg = ChatMessage.fromFirebase(pushKey, data);
    _messagesMap[msg.key] = msg;
    notifyListeners();
  }

  // ─── Send message ─────────────────────────────────────────
  Future<bool> sendMessage(int bookingId, String text) async {
    _isSending = true;
    notifyListeners();

    final result = await _chatService.sendMessage(bookingId, text);
    _isSending = false;

    if (result['success'] == true) {
      // The REST response gives us the message; Firebase will also push it.
      // Add it optimistically so it appears even before Firebase fires.
      final msg = result['data'] as ChatMessage;
      _messagesMap[msg.key] = msg;
      notifyListeners();
      return true;
    } else {
      _error = result['error']?.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Set language ─────────────────────────────────────────
  Future<bool> setLanguage(int bookingId, String languageCode) async {
    final result = await _chatService.setLanguage(bookingId, languageCode);
    if (result['success'] == true) {
      _session = result['data'] as ChatSession;
      // Re-load messages so translated_text is fetched in the new language
      await loadMessages(bookingId, refresh: true);
      notifyListeners();
      return true;
    } else {
      _error = result['error']?.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Fetch supported languages ────────────────────────────
  Future<void> fetchSupportedLanguages() async {
    if (_supportedLanguages != null) return; // cached
    final result = await _chatService.getSupportedLanguages();
    if (result['success'] == true) {
      _supportedLanguages = result['data'] as SupportedLanguages;
      notifyListeners();
    }
  }

  // ─── Reset state when leaving a chat ─────────────────────
  void reset() {
    _session = null;
    _messagesMap.clear();
    _error = null;
    _isLoadingSession = false;
    _isLoadingMessages = false;
    _isSending = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

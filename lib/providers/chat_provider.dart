import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();

  ChatSession? _session;
  final List<ChatMessage> _messages = [];
  final Set<String> _seenFirebaseKeys = <String>{};
  final Set<int> _seenMessageIds = <int>{};
  Map<String, String> _supportedLanguages = const {};
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  int? _activeBookingId;
  int _openGeneration = 0;
  bool _isDisposed = false;

  StreamSubscription<DatabaseEvent>? _addedSub;
  StreamSubscription<DatabaseEvent>? _changedSub;

  ChatSession? get session => _session;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, String> get supportedLanguages => _supportedLanguages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String get viewerLanguage => _session?.employeeLanguage ?? 'en';

  Future<bool> openChat(int bookingId) async {
    if (_activeBookingId == bookingId && _session != null) {
      return true;
    }
    final myGen = ++_openGeneration;
    _activeBookingId = bookingId;
    _isLoading = true;
    _error = null;
    _messages.clear();
    _seenFirebaseKeys.clear();
    _seenMessageIds.clear();
    _safeNotify();

    final sessionResult = await _chatService.openSession(bookingId);
    if (myGen != _openGeneration || _isDisposed) return false;
    if (sessionResult['success'] != true) {
      _isLoading = false;
      _error = sessionResult['error']?.toString() ?? 'Could not open chat';
      _safeNotify();
      return false;
    }
    _session = sessionResult['data'] as ChatSession;

    final history = await _chatService.fetchMessages(bookingId, skip: 0, limit: 100);
    if (myGen != _openGeneration || _isDisposed) return false;
    if (history['success'] == true) {
      final list = history['messages'] as List<ChatMessage>? ?? [];
      _messages.clear();
      for (final m in list) {
        _addToSeen(m);
        _messages.add(m);
      }
      _messages.sort((a, b) => a.sortTime.compareTo(b.sortTime));
      if (history['session'] is ChatSession) {
        _session = history['session'] as ChatSession;
      }
    } else {
      _error = history['error']?.toString() ?? 'Could not load chat history';
    }

    final path = _session?.firebasePath;
    if (path == null || path.isEmpty) {
      _error = _error ?? 'Chat is not available right now (no realtime path).';
      _isLoading = false;
      _safeNotify();
      return false;
    }

    _attachFirebaseListeners(path);

    if (_supportedLanguages.isEmpty) {
      unawaited(_loadLanguages());
    }

    _isLoading = false;
    _safeNotify();
    return true;
  }

  void _addToSeen(ChatMessage m) {
    if (m.firebaseMessageId != null && m.firebaseMessageId!.isNotEmpty) {
      _seenFirebaseKeys.add(m.firebaseMessageId!);
    }
    if (m.id != null) {
      _seenMessageIds.add(m.id!);
    }
  }

  Future<void> _loadLanguages() async {
    final result = await _chatService.fetchSupportedLanguages();
    if (_isDisposed) return;
    // Accept the languages map whether the call fully succeeded or fell back
    // to the static list — the picker is more useful than an empty sheet.
    if (result['languages'] is Map<String, String>) {
      _supportedLanguages = result['languages'] as Map<String, String>;
      _safeNotify();
    }
    if (result['success'] != true && result['error'] != null) {
      debugPrint('ChatProvider supported-languages fallback: ${result['error']}');
    }
  }

  void _attachFirebaseListeners(String path) {
    _addedSub?.cancel();
    _changedSub?.cancel();

    _addedSub = _chatService.onMessageAdded(path).listen((event) {
      if (_isDisposed) return;
      final snap = event.snapshot;
      if (snap.key == null || snap.value == null) return;
      if (snap.value is! Map) return;
      final key = snap.key!;
      if (_seenFirebaseKeys.contains(key)) return;
      final msg = ChatMessage.fromFirebase(key, snap.value as Map);
      _seenFirebaseKeys.add(key);
      if (msg.id != null) _seenMessageIds.add(msg.id!);
      _messages.add(msg);
      _messages.sort((a, b) => a.sortTime.compareTo(b.sortTime));
      _safeNotify();
    }, onError: (Object e) {
      if (_isDisposed) return;
      _error = 'Realtime connection error: $e';
      debugPrint('ChatProvider onChildAdded error: $e');
      _safeNotify();
    });

    _changedSub = _chatService.onMessageChanged(path).listen((event) {
      if (_isDisposed) return;
      final snap = event.snapshot;
      if (snap.key == null || snap.value == null) return;
      if (snap.value is! Map) return;
      final updated = ChatMessage.fromFirebase(snap.key!, snap.value as Map);
      final idx = _messages.indexWhere((m) => m.firebaseMessageId == updated.firebaseMessageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(
          translatedText: updated.translatedText,
          translatedTexts: updated.translatedTexts,
        );
        _safeNotify();
      }
    }, onError: (Object e) {
      if (_isDisposed) return;
      debugPrint('ChatProvider onChildChanged error: $e');
    });
  }

  Future<bool> sendMessage(String text) async {
    final bookingId = _activeBookingId;
    if (bookingId == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      _error = trimmed.isEmpty ? 'Message cannot be empty' : 'Message exceeds 2000 characters';
      _safeNotify();
      return false;
    }
    _isSending = true;
    _error = null;
    _safeNotify();

    final result = await _chatService.sendMessage(bookingId, trimmed);
    if (_isDisposed) return false;
    _isSending = false;
    if (result['success'] == true) {
      final msg = result['data'];
      if (msg is ChatMessage) {
        final keyAlreadySeen = msg.firebaseMessageId != null && _seenFirebaseKeys.contains(msg.firebaseMessageId);
        final idAlreadySeen = msg.id != null && _seenMessageIds.contains(msg.id);
        if (!keyAlreadySeen && !idAlreadySeen) {
          _addToSeen(msg);
          _messages.add(msg);
          _messages.sort((a, b) => a.sortTime.compareTo(b.sortTime));
        }
      }
      _safeNotify();
      return true;
    }
    _error = result['error']?.toString() ?? 'Failed to send';
    _safeNotify();
    return false;
  }

  Future<bool> updateLanguage(String code) async {
    final bookingId = _activeBookingId;
    if (bookingId == null) return false;
    if (_supportedLanguages.isNotEmpty && !_supportedLanguages.containsKey(code)) {
      _error = 'Language "$code" is not supported';
      _safeNotify();
      return false;
    }
    final result = await _chatService.setLanguage(bookingId, code);
    if (_isDisposed) return false;
    if (result['success'] == true) {
      final updated = result['data'];
      if (updated is ChatSession) {
        _session = updated;
      } else if (_session != null) {
        _session = _session!.copyWith(employeeLanguage: code);
      }
      _safeNotify();
      return true;
    }
    _error = result['error']?.toString() ?? 'Failed to update language';
    _safeNotify();
    return false;
  }

  Future<void> ensureLanguages() async {
    if (_supportedLanguages.isEmpty) {
      await _loadLanguages();
    }
  }

  void closeChat({bool notify = true}) {
    _openGeneration++;
    _addedSub?.cancel();
    _changedSub?.cancel();
    _addedSub = null;
    _changedSub = null;
    _session = null;
    _messages.clear();
    _seenFirebaseKeys.clear();
    _seenMessageIds.clear();
    _activeBookingId = null;
    _error = null;
    _isLoading = false;
    _isSending = false;
    // When invoked from a widget's dispose() we must NOT notifyListeners()
    // during teardown — it can trigger 'markNeedsBuild during dispose' for any
    // other listener of this app-scoped provider. Resetting silently is safe
    // because the screen being torn down is no longer listening.
    if (notify) _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _addedSub?.cancel();
    _changedSub?.cancel();
    super.dispose();
  }
}

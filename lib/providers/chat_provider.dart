import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  // ─── Chat state ───────────────────────────────────────────
  ChatSession? _session;
  final Map<String, ChatMessage> _messagesMap = {}; // key = ChatMessage.key
  SupportedLanguages? _supportedLanguages;

  bool _isLoadingSession = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _error;

  // ─── Firebase listener state ──────────────────────────────
  // The listener lives here (singleton) so it survives screen close.
  StreamSubscription<DatabaseEvent>? _childAddedSub;
  StreamSubscription<DatabaseEvent>? _childChangedSub;
  String? _activeFirebasePath;
  bool _listenerHadError = false;
  // Max epoch-ms timestamp from the last REST load — used by .startAfter()
  // so Firebase delivers ONLY messages that arrive after the REST history.
  int? _lastRestTimestamp;

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
      if (result['session'] != null) {
        final newSession = result['session'] as ChatSession;
        // The /messages endpoint does not include firebase_path in its session
        // payload, but openSession() already fetched and stored it.
        // Preserve the existing firebase_path so the listener can still start.
        _session = (newSession.firebasePath != null)
            ? newSession
            : newSession.copyWith(firebasePath: _session?.firebasePath);
      }
      // Record the latest timestamp from REST history.
      // listenToFirebase() will use .startAfter(this) so Firebase only
      // delivers messages NEWER than what REST already gave us.
      if (msgs.isNotEmpty) {
        _lastRestTimestamp = msgs
            .map((m) => m.sortTime.millisecondsSinceEpoch)
            .reduce((a, b) => a > b ? a : b);
      }
    } else {
      _error = result['error']?.toString();
    }
    notifyListeners();
  }

  // ─── Firebase RTDB listener (idempotent, survives screen close) ───────────
  //
  // Rules:
  //   • Same path, no error, already subscribed → do nothing (no duplicate events)
  //   • Different path or prior error → cancel old sub, re-subscribe
  //   • .startAfter(_lastRestTimestamp) ensures Firebase skips all messages
  //     already loaded by REST, delivering only new ones (msg #80, #81…)
  void listenToFirebase(String path) {
    final alreadyListening = _childAddedSub != null &&
        _activeFirebasePath == path &&
        !_listenerHadError;
    if (alreadyListening) return;

    // Cancel stale subscriptions before re-subscribing.
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _listenerHadError = false;
    _activeFirebasePath = path;

    final ref = FirebaseDatabase.instance.ref(path);

    // If we have REST history, start AFTER the last known timestamp so
    // Firebase doesn't replay old messages as onChildAdded events.
    // Cast to double: RTDB stores numbers as IEEE-754 doubles (JavaScript
    // semantics), so comparing an int against a double-indexed field can
    // silently miss the boundary. Passing a double is always safe.
    final Query query = _lastRestTimestamp != null
        ? ref.orderByChild('timestamp').startAfter(_lastRestTimestamp!.toDouble())
        : ref.orderByChild('timestamp');

    // New message from driver (or own message echoed back)
    _childAddedSub = query.onChildAdded.listen(
      (event) {
        final key = event.snapshot.key;
        final value = event.snapshot.value;
        if (key != null && value != null && value is Map) {
          applyFirebaseMessage(key, value);
        }
      },
      onError: (e) {
        debugPrint('[ChatProvider] Firebase childAdded error: $e');
        _listenerHadError = true;
      },
    );

    // Translation patch arrives ~1 s after the original message
    _childChangedSub = query.onChildChanged.listen(
      (event) {
        final key = event.snapshot.key;
        final value = event.snapshot.value;
        if (key != null && value != null && value is Map) {
          applyFirebaseMessage(key, value);
        }
      },
      onError: (e) {
        debugPrint('[ChatProvider] Firebase childChanged error: $e');
        _listenerHadError = true;
      },
    );
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
      // Add optimistically; Firebase will also echo it back (deduped by key).
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
      // Full refresh: reload messages with translations in the new language.
      await loadMessages(bookingId, refresh: true);
      // After a full refresh, _lastRestTimestamp has changed. Force the Firebase
      // listener to re-subscribe with the new startAfter boundary so it doesn't
      // use the stale timestamp from the previous session.
      _listenerHadError = true; // trips the idempotency guard in listenToFirebase
      if (_activeFirebasePath != null) {
        listenToFirebase(_activeFirebasePath!);
      }
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

  // ─── Cancel Firebase listener ─────────────────────────────
  // Call this ONLY when switching to a completely different booking.
  // Do NOT call on screen close — the listener must survive dispose().
  void cancelFirebaseListener() {
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childAddedSub = null;
    _childChangedSub = null;
    _activeFirebasePath = null;
    _listenerHadError = false;
    _lastRestTimestamp = null;
  }

  // ─── Reset for a new booking ──────────────────────────────
  // Cancels the listener AND wipes message state.
  // Call when opening a different booking than the one currently loaded.
  void resetForNewBooking() {
    cancelFirebaseListener();
    _session = null;
    _messagesMap.clear();
    _error = null;
    _isLoadingSession = false;
    _isLoadingMessages = false;
    _isSending = false;
    notifyListeners();
  }

  // ─── Soft reset (same booking re-entered) ────────────────
  // Clears error/loading flags but keeps messages + listener alive.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

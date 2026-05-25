import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../providers/chat_provider.dart';

// ─────────────────────────────────────────────────────────────────
// ChatScreen
// Entry: push MaterialPageRoute with bookingId + bookingStatus
// ─────────────────────────────────────────────────────────────────

/// Tracks the booking whose chat screen is currently open.
/// NotificationService reads this to suppress the banner when the
/// user is already looking at that conversation.
class ActiveChat {
  static int? bookingId;
}

const int _kMaxMessageLength = 1000;

class ChatScreen extends StatefulWidget {
  final int bookingId;
  final String? bookingStatus;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.bookingStatus,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  StreamSubscription<DatabaseEvent>? _childAddedSub;
  StreamSubscription<DatabaseEvent>? _childChangedSub;
  DatabaseReference? _messagesRef;

  bool _isInitializing = true;
  String? _initError;
  int _charCount = 0;

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    ActiveChat.bookingId = widget.bookingId; // mark screen as open
    _textController.addListener(() {
      setState(() => _charCount = _textController.text.length);
    });
    _initialize();
  }

  @override
  void dispose() {
    ActiveChat.bookingId = null; // mark screen as closed
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Init: open session → load REST messages → attach Firebase ──

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    final chatProvider = context.read<ChatProvider>();
    chatProvider.reset();

    // 1. Open / retrieve the session
    final sessionOk = await chatProvider.openSession(widget.bookingId);
    if (!mounted) return;

    if (!sessionOk) {
      setState(() {
        _isInitializing = false;
        _initError = chatProvider.error ?? 'Could not open chat session';
      });
      return;
    }

    // 2. Load initial message history from REST API
    await chatProvider.loadMessages(widget.bookingId);
    if (!mounted) return;

    // 3. Attach Firebase RTDB listener on the session's firebase_path
    final firebasePath = chatProvider.session?.firebasePath;
    if (firebasePath != null && firebasePath.isNotEmpty) {
      _attachFirebaseListener(firebasePath);
    }

    // 4. Fetch supported languages (cached after first call)
    chatProvider.fetchSupportedLanguages();

    setState(() => _isInitializing = false);
    _scrollToBottom();
  }

  // ── Firebase RTDB listener ─────────────────────────────────

  void _attachFirebaseListener(String path) {
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();

    _messagesRef = FirebaseDatabase.instance.ref(path);

    // firebase_message_id is now a UUID (not a time-ordered push key), so we
    // must order by the 'timestamp' field instead of by key.
    final query = _messagesRef!.orderByChild('timestamp');

    // New message arrived
    _childAddedSub = query.onChildAdded.listen((event) {
      if (!mounted) return;
      final key = event.snapshot.key;
      final value = event.snapshot.value;
      if (key != null && value != null && value is Map) {
        context.read<ChatProvider>().applyFirebaseMessage(key, value);
        _scrollToBottom();
      }
    });

    // Translation patch arrives ~1 s after the original message
    _childChangedSub = query.onChildChanged.listen((event) {
      if (!mounted) return;
      final key = event.snapshot.key;
      final value = event.snapshot.value;
      if (key != null && value != null && value is Map) {
        context.read<ChatProvider>().applyFirebaseMessage(key, value);
      }
    });
  }

  // ── Send message ───────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Client-side length guard (API enforces 1000 chars)
    if (text.length > _kMaxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Message is too long. Maximum $_kMaxMessageLength characters allowed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();

    final chatProvider = context.read<ChatProvider>();
    final success = await chatProvider.sendMessage(widget.bookingId, text);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.error ?? 'Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
    _scrollToBottom();
  }

  // ── Language picker bottom sheet ───────────────────────────

  void _showLanguagePicker() {
    final chatProvider = context.read<ChatProvider>();
    final langs = chatProvider.supportedLanguages?.languages ?? {};
    final currentLang = chatProvider.session?.employeeLanguage ?? 'en';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        languages: langs,
        currentCode: currentLang,
        onSelected: (code) async {
          Navigator.pop(context);
          final ok = await chatProvider.setLanguage(widget.bookingId, code);
          if (mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(chatProvider.error ?? 'Failed to set language'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  // ── Scroll helper ──────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _isInitializing
          ? _buildLoading()
          : _initError != null
              ? _buildError()
              : _buildChatBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF6C63FF),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chat with Driver',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Consumer<ChatProvider>(
            builder: (context2, prov, child2) {
              final session = prov.session;
              if (session == null) return const SizedBox();
              return Text(
                'Booking #${widget.bookingId}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              );
            },
          ),
        ],
      ),
      actions: [
        Consumer<ChatProvider>(
          builder: (context2, prov, child2) {
            final langCode = prov.session?.employeeLanguage ?? 'en';
            return TextButton.icon(
              onPressed: _showLanguagePicker,
              icon: const Icon(Icons.translate, color: Colors.white, size: 18),
              label: Text(
                langCode.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6C63FF)),
          SizedBox(height: 16),
          Text('Opening chat…', style: TextStyle(color: Color(0xFF636E72))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _initError ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF636E72), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        // ── Warning banner ──────────────────────────────────
        Consumer<ChatProvider>(
          builder: (context2, prov, child2) {
            final warning = prov.session?.warningMessage;
            if (warning == null || warning.isEmpty) return const SizedBox();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3CD),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF856404), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                          color: Color(0xFF856404), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Message list ────────────────────────────────────
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context2, prov, child2) {
              if (prov.isLoadingMessages && prov.messages.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF)));
              }

              final messages = prov.messages;

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No messages yet',
                          style: TextStyle(
                              color: Color(0xFF636E72), fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('Send the first message below',
                          style: TextStyle(
                              color: Color(0xFFB2BEC3), fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, i) =>
                    _MessageBubble(message: messages[i]),
              );
            },
          ),
        ),

        // ── Input bar ───────────────────────────────────────
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    // Read-only when session is inactive OR booking is in a terminal state
    final sessionInactive =
        context.watch<ChatProvider>().session?.isActive == false;
    final statusReadOnly = widget.bookingStatus == 'Cancelled' ||
        widget.bookingStatus == 'No-Show';

    if (sessionInactive || statusReadOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: const Text(
          'This chat is now read-only.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF636E72), fontSize: 13),
        ),
      );
    }

    // Show character counter only when approaching the limit (> 800)
    final nearLimit = _charCount > 800;
    final overLimit = _charCount > _kMaxMessageLength;
    final counterColor = overLimit
        ? Colors.red
        : nearLimit
            ? Colors.orange
            : Colors.grey;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLength: _kMaxMessageLength,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: TextStyle(color: Color(0xFFB2BEC3)),
                        border: InputBorder.none,
                        counterText: '', // we draw our own counter below
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<ChatProvider>(
                  builder: (context2, prov, child2) {
                    return prov.isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF6C63FF)),
                            ),
                          )
                        : IconButton(
                            onPressed: overLimit ? null : _sendMessage,
                            icon: const Icon(Icons.send_rounded),
                            color: overLimit
                                ? Colors.grey
                                : const Color(0xFF6C63FF),
                            iconSize: 26,
                            tooltip: 'Send',
                          );
                  },
                ),
              ],
            ),
            // Character counter — visible only when > 800
            if (nearLimit)
              Padding(
                padding: const EdgeInsets.only(right: 52, top: 2),
                child: Text(
                  '$_charCount / $_kMaxMessageLength',
                  style: TextStyle(fontSize: 11, color: counterColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Message Bubble Widget
// ─────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return _SystemBubble(message: message);
    }
    final isEmployee = message.senderType == 'employee';
    return _ChatBubble(message: message, isEmployee: isEmployee);
  }
}

class _SystemBubble extends StatelessWidget {
  final ChatMessage message;
  const _SystemBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082), width: 1),
          ),
          child: Text(
            message.translatedText.isNotEmpty
                ? message.translatedText
                : message.originalText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5D4037),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isEmployee;

  const _ChatBubble({required this.message, required this.isEmployee});

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isEmployee ? const Color(0xFF6C63FF) : const Color(0xFFECEFF1);
    final textColor = isEmployee ? Colors.white : const Color(0xFF2D3436);
    final timeColor = isEmployee
        ? Colors.white.withOpacity(0.7)
        : const Color(0xFF636E72);

    final displayText = message.translatedText.isNotEmpty
        ? message.translatedText
        : message.originalText;

    final timeStr = message.createdAt != null
        ? DateFormat('h:mm a').format(message.createdAt!.toLocal())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isEmployee ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isEmployee) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
              child: const Icon(Icons.person,
                  size: 16, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isEmployee ? 18 : 4),
                  bottomRight: Radius.circular(isEmployee ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isEmployee)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Driver',
                        style: TextStyle(
                          color: const Color(0xFF6C63FF).withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    displayText,
                    style: TextStyle(
                        color: textColor, fontSize: 14.5, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.translatedText.isNotEmpty &&
                          message.translatedText != message.originalText)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.translate,
                              size: 11, color: timeColor),
                        ),
                      Text(timeStr,
                          style: TextStyle(color: timeColor, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isEmployee) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
              child: const Icon(Icons.person,
                  size: 16, color: Color(0xFF6C63FF)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Language Selection Bottom Sheet
// ─────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  final Map<String, String> languages;
  final String currentCode;
  final void Function(String code) onSelected;

  const _LanguageSheet({
    required this.languages,
    required this.currentCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = {
      'en': 'English', 'hi': 'Hindi', 'ar': 'Arabic', 'fr': 'French',
      'de': 'German', 'es': 'Spanish', 'zh': 'Chinese (Simplified)',
      'ja': 'Japanese', 'ko': 'Korean', 'pt': 'Portuguese', 'ru': 'Russian',
      'it': 'Italian', 'ta': 'Tamil', 'te': 'Telugu', 'kn': 'Kannada',
      'ml': 'Malayalam', 'mr': 'Marathi', 'bn': 'Bengali', 'gu': 'Gujarati',
      'pa': 'Punjabi', 'ur': 'Urdu',
    };
    final displayLangs = languages.isNotEmpty ? languages : fallback;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Choose Your Language',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436)),
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView(
              shrinkWrap: true,
              children: displayLangs.entries.map((entry) {
                final isSelected = entry.key == currentCode;
                return ListTile(
                  onTap: () => onSelected(entry.key),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFF1F3F4),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF636E72)),
                    ),
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF2D3436),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF6C63FF))
                      : null,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

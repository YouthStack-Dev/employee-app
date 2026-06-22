import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/chat_message_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/fx_widgets.dart';

class ChatScreen extends StatefulWidget {
  final int bookingId;
  final String? driverName;

  const ChatScreen({super.key, required this.bookingId, this.driverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatProvider? _chatRef;
  AuthProvider? _authRef;
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComposerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatRef = Provider.of<ChatProvider>(context, listen: false);
    _authRef = Provider.of<AuthProvider>(context, listen: false);
    if (!_initStarted) {
      _initStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initChat();
      });
    }
  }

  void _onComposerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initChat() async {
    final chat = _chatRef;
    if (chat == null) return;
    final ok = await chat.openChat(widget.bookingId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.error ?? 'Could not open chat'),
          backgroundColor: FxColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _chatRef?.closeChat(notify: false);
    super.dispose();
  }

  Future<void> _onSend() async {
    final chat = _chatRef;
    if (chat == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty || chat.isSending) return;
    _controller.clear();
    final ok = await chat.sendMessage(text);
    if (!mounted) return;
    if (ok) {
      _scrollToEnd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chat.error ?? 'Failed to send'),
          backgroundColor: FxColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _openLanguagePicker() async {
    final chat = _chatRef;
    if (chat == null) return;
    await chat.ensureLanguages();
    if (!mounted) return;
    final current = chat.viewerLanguage;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final langs = chat.supportedLanguages.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              decoration: BoxDecoration(
                color: FxColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(28),
                boxShadow: FxShadows.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FxColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Select chat language', style: FxText.headlineSm()),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: langs.length,
                      itemBuilder: (_, i) {
                        final entry = langs[i];
                        final isSelected = entry.key == current;
                        return ListTile(
                          title: Text(entry.value, style: FxText.body()),
                          subtitle: Text(entry.key.toUpperCase(), style: FxText.labelSm()),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: FxColors.primary)
                              : null,
                          onTap: () => Navigator.pop(ctx, entry.key),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (selected != null && selected != current) {
      final ok = await chat.updateLanguage(selected);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chat.error ?? 'Failed to switch language'),
            backgroundColor: FxColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        bottom: false,
        child: Consumer<ChatProvider>(
          builder: (context, chat, _) {
            final messages = chat.messages;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (!_scrollController.hasClients || messages.isEmpty) return;
              final atBottom =
                  _scrollController.offset >= _scrollController.position.maxScrollExtent - 100;
              if (atBottom) _scrollToEnd();
            });
            return Column(
              children: [
                _header(chat),
                Expanded(child: _buildMessageList(chat)),
                _composer(chat),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(ChatProvider chat) {
    final title = widget.driverName != null && widget.driverName!.isNotEmpty
        ? widget.driverName!
        : 'Booking #${widget.bookingId}';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      decoration: const BoxDecoration(
        color: FxColors.surfaceContainerLowest,
        boxShadow: FxShadows.soft,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: FxGradients.indigo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car_rounded, color: FxColors.onPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FxText.title(), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  chat.session == null ? 'Connecting…' : 'Language: ${chat.viewerLanguage.toUpperCase()}',
                  style: FxText.bodySm(),
                ),
              ],
            ),
          ),
          Material(
            color: FxColors.surfaceContainerLow,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: chat.session == null ? null : _openLanguagePicker,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.translate_rounded, color: FxColors.primary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chat) {
    if (chat.isLoading && chat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: FxColors.primary));
    }
    if (chat.session == null && chat.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: FxColors.error, size: 56),
              const SizedBox(height: 12),
              Text(chat.error!, textAlign: TextAlign.center, style: FxText.body(color: FxColors.error)),
              const SizedBox(height: 18),
              SizedBox(
                width: 200,
                child: FxPrimaryButton(
                  label: 'Retry',
                  leadingIcon: Icons.refresh_rounded,
                  onPressed: _initChat,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final employeeId = _authRef?.user?.employeeId;
    final viewerLang = chat.viewerLanguage;
    final messages = chat.messages;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: FxColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: FxColors.outline, size: 40),
            ),
            const SizedBox(height: 18),
            Text('No messages yet', style: FxText.headlineSm()),
            const SizedBox(height: 4),
            Text('Say hi to your driver!', style: FxText.body(color: FxColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        if (msg.isSystemMessage || msg.senderType == 'system') {
          return _systemBubble(msg, viewerLang);
        }
        // Fail closed: only "mine" when both identities are known and equal.
        final isMine = msg.senderType == 'employee' &&
            employeeId != null &&
            msg.senderId != null &&
            msg.senderId == employeeId;
        return _messageBubble(msg, isMine, viewerLang);
      },
    );
  }

  Widget _systemBubble(ChatMessage msg, String viewerLang) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5C66B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB7791F), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg.displayText(viewerLang),
              style: FxText.bodySm(color: const Color(0xFF7A5A00)).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg, bool isMine, String viewerLang) {
    final textColor = isMine ? FxColors.onPrimary : FxColors.onSurface;
    final timeStr = DateFormat('HH:mm').format(msg.sortTime.toLocal());
    final showOriginal = msg.originalLanguage != null &&
        msg.originalLanguage!.isNotEmpty &&
        msg.originalLanguage != viewerLang &&
        msg.displayText(viewerLang) != msg.originalText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMine ? FxGradients.indigo : null,
          color: isMine ? null : FxColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: isMine ? null : FxShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.displayText(viewerLang), style: FxText.body(color: textColor)),
            if (showOriginal) ...[
              const SizedBox(height: 4),
              Text(
                'Original (${msg.originalLanguage!.toUpperCase()}): ${msg.originalText}',
                style: FxText.bodySm(
                  color: isMine ? FxColors.onPrimary.withOpacity(0.75) : FxColors.onSurfaceVariant,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: FxText.labelSm(
                color: isMine ? FxColors.onPrimary.withOpacity(0.7) : FxColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ChatProvider chat) {
    final disabled = chat.session == null;
    final length = _controller.text.characters.length;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: FxColors.surfaceContainerLowest,
        boxShadow: FxShadows.bottomNav,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FxColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    style: FxText.body(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: disabled || chat.isSending ? FxColors.outline : FxColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: disabled || chat.isSending ? null : _onSend,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: chat.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FxColors.onPrimary),
                          )
                        : const Icon(Icons.send_rounded, color: FxColors.onPrimary, size: 22),
                  ),
                ),
              ),
            ],
          ),
          if (length > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                '$length / 2000',
                style: FxText.labelSm(
                  color: length > 2000
                      ? FxColors.error
                      : (length > 1800 ? FxColors.amber : FxColors.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

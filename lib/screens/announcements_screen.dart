import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/announcement_model.dart';
import '../providers/announcement_provider.dart';
import '../widgets/fx_widgets.dart';
import 'announcement_detail_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String _filter = 'all'; // all, unread

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnouncementProvider>(context, listen: false).fetchInbox();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.play_circle_filled_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'link': return Icons.link_rounded;
      default: return Icons.campaign_rounded;
    }
  }

  Color _tintFor(String type) {
    switch (type) {
      case 'image': return FxColors.tertiary;
      case 'video': return FxColors.error;
      case 'audio': return FxColors.secondary;
      case 'pdf': return const Color(0xFFE17055);
      case 'link': return const Color(0xFF00B894);
      default: return FxColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Consumer<AnnouncementProvider>(
          builder: (context, provider, _) {
            final items = _filter == 'unread'
                ? provider.inbox.where((a) => a.deliveryStatus != 'read').toList()
                : provider.inbox;
            return RefreshIndicator(
              color: FxColors.primary,
              onRefresh: () => provider.fetchInbox(refresh: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _topBar()),
                  SliverToBoxAdapter(child: _filterRow(provider.unreadCount)),
                  if (provider.isLoading && provider.inbox.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: FxColors.primary)),
                    )
                  else if (provider.error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorView(provider.error!, () => provider.fetchInbox(refresh: true)),
                    )
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _announcementCard(items[i]),
                          ),
                          childCount: items.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('Announcements', style: FxText.headlineLg()),
        ],
      ),
    );
  }

  Widget _filterRow(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: FxSegmented(
              labels: const ['All', 'Unread'],
              selectedIndex: _filter == 'all' ? 0 : 1,
              onChanged: (i) => setState(() => _filter = i == 0 ? 'all' : 'unread'),
            ),
          ),
          const SizedBox(width: 12),
          if (unreadCount > 0)
            FxPill(text: '$unreadCount new'),
        ],
      ),
    );
  }

  Widget _announcementCard(Announcement announcement) {
    final isUnread = announcement.deliveryStatus != 'read';
    final tint = _tintFor(announcement.contentType);
    return FxCard(
      padding: const EdgeInsets.all(16),
      color: isUnread ? FxColors.surfaceContainerLowest : FxColors.surfaceContainerLow,
      showShadow: isUnread,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: announcement)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(announcement.contentType), color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: isUnread ? FxText.title() : FxText.titleSm(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: FxColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (announcement.body != null && announcement.body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    announcement.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FxText.bodySm(color: FxColors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 6),
                Text(_formatDate(announcement.publishedAt), style: FxText.labelSm()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
            child: const Icon(Icons.inbox_rounded, color: FxColors.outline, size: 40),
          ),
          const SizedBox(height: 18),
          Text('Inbox is empty', style: FxText.headlineSm()),
          const SizedBox(height: 4),
          Text("You're all caught up — new announcements will land here.",
              textAlign: TextAlign.center,
              style: FxText.body(color: FxColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _errorView(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: FxColors.error, size: 56),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: FxText.body(color: FxColors.error)),
            const SizedBox(height: 18),
            FxPrimaryButton(label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

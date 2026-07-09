import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/notification_provider.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(refresh: true);
    });
  }

  void _clearAll() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final success = await provider.clearAllNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Notifications cleared' : 'Failed to clear notifications'),
          backgroundColor: success ? FxColors.primary : FxColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final items = provider.notifications;
            return RefreshIndicator(
              color: FxColors.primary,
              onRefresh: () => provider.fetchNotifications(refresh: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _topBar(provider)),
                  if (provider.isLoading && provider.notifications.isEmpty)
                    SliverToBoxAdapter(
                      child: const Column(
                        children: [
                          SizedBox(height: 16),
                          SkeletonNotificationRow(),
                          SizedBox(height: 8),
                          SkeletonNotificationRow(),
                          SizedBox(height: 8),
                          SkeletonNotificationRow(),
                          SizedBox(height: 8),
                          SkeletonNotificationRow(),
                          SizedBox(height: 8),
                          SkeletonNotificationRow(),
                        ],
                      ),
                    )
                  else if (provider.error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorView(provider.error!, () => provider.fetchNotifications(refresh: true)),
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
                            child: _notificationCard(items[i]),
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

  Widget _topBar(NotificationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text('Notifications', style: FxText.headlineLg())),
          if (provider.notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text('Clear All', style: FxText.titleSm(color: FxColors.error)),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 48, color: FxColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('No notifications', style: FxText.headlineMd()),
          const SizedBox(height: 8),
          Text("You're all caught up.", style: FxText.body()),
        ],
      ),
    );
  }

  Widget _errorView(String err, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: FxColors.error, size: 48),
            const SizedBox(height: 16),
            Text(err, textAlign: TextAlign.center, style: FxText.body()),
            const SizedBox(height: 16),
            FxPrimaryButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(dynamic item) {
    return FxCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active_rounded, color: FxColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: FxText.title(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(item.createdAt, style: FxText.bodySm(color: FxColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.message,
                  style: FxText.body(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

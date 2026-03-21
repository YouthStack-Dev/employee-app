import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/announcement_model.dart';
import '../providers/announcement_provider.dart';
import '../constants/app_colors.dart';
import 'announcement_detail_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnouncementProvider>(context, listen: false).fetchInbox();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'video': return Icons.play_circle_filled;
      case 'audio': return Icons.audiotrack;
      case 'pdf': return Icons.picture_as_pdf;
      case 'link': return Icons.link;
      default: return Icons.campaign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnnouncementProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchInbox(refresh: true),
        child: provider.isLoading && provider.inbox.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 150),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(provider.error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () => provider.fetchInbox(refresh: true),
                              child: const Text('Try Again'),
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                : provider.inbox.isEmpty
                    ? ListView(
                        // listview so refresh indicator still works on empty
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No announcements yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          )
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: provider.inbox.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final a = provider.inbox[index];
                          final isUnread = a.deliveryStatus != 'read';

                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnnouncementDetailScreen(announcement: a),
                                ),
                              );
                            },
                            tileColor: isUnread ? Colors.blue.shade50.withOpacity(0.3) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isUnread ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                              child: Icon(
                                _getIconForType(a.contentType),
                                color: isUnread ? AppColors.primary : Colors.grey,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.title,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (a.body != null && a.body!.isNotEmpty)
                                  Text(
                                    a.body!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(a.publishedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
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
}

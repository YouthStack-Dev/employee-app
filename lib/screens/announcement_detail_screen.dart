import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/announcement_model.dart';
import '../providers/announcement_provider.dart';
import '../providers/time_format_provider.dart';
import '../utils/time_format.dart';
import '../constants/app_colors.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final Announcement announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Mark as read immediately on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnnouncementProvider>(context, listen: false)
          .markAsRead(widget.announcement.announcementId);
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return formatDateWithClock(date, is24Hour: context.watch<TimeFormatProvider>().is24Hour);
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL provided.')),
        );
      }
    }
  }

  Widget _buildMediaContent() {
    final mediaUrl = widget.announcement.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return const SizedBox.shrink();

    switch (widget.announcement.contentType) {
      case 'image':
        return Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
            ),
          ),
        );
      
      case 'link':
      case 'pdf':
      case 'video':
      case 'audio':
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: ElevatedButton.icon(
            onPressed: () => _launchUrl(mediaUrl),
            icon: Icon(
              widget.announcement.contentType == 'pdf' ? Icons.picture_as_pdf
              : widget.announcement.contentType == 'video' ? Icons.play_arrow
              : Icons.open_in_browser,
              color: Colors.white,
            ),
            label: Text(
              widget.announcement.mediaFilename ?? 'Open Attachment',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Date
            Text(
              _formatDate(a.publishedAt),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            // Body
            if (a.body != null && a.body!.isNotEmpty)
              Text(
                a.body!,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            
            // Media
            _buildMediaContent(),
          ],
        ),
      ),
    );
  }
}

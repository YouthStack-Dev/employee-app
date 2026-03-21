import 'package:flutter/material.dart';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementService _service = AnnouncementService();

  List<Announcement> _inbox = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<Announcement> get inbox => _inbox;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> fetchInbox({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getInbox();
      
      if (result['success']) {
        _inbox = result['data'] as List<Announcement>;
        _calculateUnreadCount();
      } else {
        _error = result['error'] ?? 'Failed to load announcements';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateUnreadCount() {
    _unreadCount = _inbox.where((a) => a.deliveryStatus != 'read').length;
  }

  Future<void> markAsRead(int announcementId) async {
    // Optimistic UI update
    final index = _inbox.indexWhere((a) => a.announcementId == announcementId);
    if (index == -1) return;

    final originalAnnouncement = _inbox[index];
    if (originalAnnouncement.deliveryStatus == 'read') return; // already read

    // Update locally
    _inbox[index] = Announcement(
      announcementId: originalAnnouncement.announcementId,
      title: originalAnnouncement.title,
      body: originalAnnouncement.body,
      contentType: originalAnnouncement.contentType,
      mediaUrl: originalAnnouncement.mediaUrl,
      mediaFilename: originalAnnouncement.mediaFilename,
      publishedAt: originalAnnouncement.publishedAt,
      deliveryStatus: 'read',
      readAt: DateTime.now(),
      recipientId: originalAnnouncement.recipientId,
    );
    _calculateUnreadCount();
    notifyListeners();

    try {
      // Fire API call asynchronously (fire & forget)
      final result = await _service.markAsRead(announcementId);

      // Rollback if failed
      if (!result['success']) {
        final currentIndex = _inbox.indexWhere((a) => a.announcementId == announcementId);
        if (currentIndex != -1) {
           _inbox[currentIndex] = originalAnnouncement;
           _error = result['error'] ?? 'Failed to mark as read on server';
           _calculateUnreadCount();
           notifyListeners();
        }
      }
    } catch (e) {
      final currentIndex = _inbox.indexWhere((a) => a.announcementId == announcementId);
      if (currentIndex != -1) {
         _inbox[currentIndex] = originalAnnouncement;
         _error = 'Failed to mark as read: $e';
         _calculateUnreadCount();
         notifyListeners();
      }
    }
  }
}

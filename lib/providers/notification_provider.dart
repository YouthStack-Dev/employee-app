import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  int _currentPage = 1;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _notifications.clear();
      _hasMore = true;
      _error = null;
    }

    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    final result = await _service.getNotifications(page: _currentPage, pageSize: 20);

    if (result['success'] == true) {
      final List<NotificationModel> fetched = result['data'] ?? [];
      if (fetched.isEmpty) {
        _hasMore = false;
      } else {
        _notifications.addAll(fetched);
        _currentPage++;
      }
      _error = null;
    } else {
      _error = result['error'] ?? 'Failed to load notifications';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> clearAllNotifications() async {
    _isLoading = true;
    notifyListeners();

    final result = await _service.clearNotifications();

    if (result['success'] == true) {
      _notifications.clear();
      _hasMore = false;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _error = result['error'] ?? 'Failed to clear notifications';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

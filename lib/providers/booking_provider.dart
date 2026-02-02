import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

enum BookingType { home, history }

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  
  List<Booking> _homeBookings = [];
  List<Booking> _historyBookings = [];
  
  bool _isLoading = false;
  String? _error;

  List<Booking> get homeBookings => _homeBookings;
  List<Booking> get historyBookings => _historyBookings;
  
  // Backward compatibility getter if needed, but better to force usage of specific lists
  // List<Booking> get bookings => _homeBookings; 

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _bookingService.cancelBooking(bookingId);

      if (result['success']) {
        // Update status locally instead of removing, as per user request
        _updateBookingStatusLocally(bookingId, 'Cancelled');
        _error = null;
      } else {
        _error = result['error'];
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = 'Unexpected error: $e';
      notifyListeners();
      return {'success': false, 'error': _error};
    }
  }

  void _updateBookingStatusLocally(int id, String newStatus) {
    // Helper to update status in both lists if present
    for (int i = 0; i < _homeBookings.length; i++) {
      if (_homeBookings[i].id == id) {
        _homeBookings[i] = _homeBookings[i].copyWith(status: newStatus);
      }
    }
    for (int i = 0; i < _historyBookings.length; i++) {
      if (_historyBookings[i].id == id) {
        _historyBookings[i] = _historyBookings[i].copyWith(status: newStatus);
      }
    }
  }
  
  Future<void> fetchBookings(int employeeId, {String? startDate, String? endDate, BookingType type = BookingType.home}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _bookingService.fetchBookings(employeeId: employeeId, startDate: startDate, endDate: endDate);

    _isLoading = false;
    if (result['success']) {
      List<Booking> fetched = result['data'];
      if (type == BookingType.home) {
        _homeBookings = fetched;
      } else {
        _historyBookings = fetched;
      }
      _error = null;
    } else {
      _error = result['error'];
    }
    notifyListeners();
  }
}

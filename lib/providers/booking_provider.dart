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

  Future<Map<String, dynamic>> cancelBooking(int bookingId, {String? reason}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _bookingService.cancelBooking(bookingId, reason: reason);

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

    print('🔵 PROVIDER: Calling fetchBookings for employeeId=$employeeId, type=$type');
    final result = await _bookingService.fetchBookings(employeeId: employeeId, startDate: startDate, endDate: endDate);

    _isLoading = false;
    print('🔵 PROVIDER: Result success=${result['success']}, error=${result['error']}');
    
    if (result['success']) {
      final rawData = result['data'];
      print('🔵 PROVIDER: rawData type=${rawData.runtimeType}, length=${rawData is List ? rawData.length : 'N/A'}');
      List<Booking> fetched = [];
      
      if (rawData is List) {
         try {
             fetched = rawData.cast<Booking>();
         } catch (e) {
             print('🔵 PROVIDER: cast<Booking> failed: $e, using List.from fallback');
             // Fallback if cast fails
             fetched = List<Booking>.from(rawData);
         }
      }
      
      print('🔵 PROVIDER: fetched ${fetched.length} bookings for type=$type');
      if (fetched.isNotEmpty) {
        print('🔵 PROVIDER: First booking id=${fetched[0].id}, status=${fetched[0].status}, date=${fetched[0].date}');
      }
      
      if (type == BookingType.home) {
        _homeBookings = fetched;
        print('🔵 PROVIDER: Set _homeBookings, now has ${_homeBookings.length} items');
      } else {
        _historyBookings = fetched;
        print('🔵 PROVIDER: Set _historyBookings, now has ${_historyBookings.length} items');
      }
      _error = null;
    } else {
      _error = result['error'];
      print('🔵 PROVIDER: ERROR = $_error');
    }
    notifyListeners();
  }
}

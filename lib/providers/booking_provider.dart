import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();
  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _error;

  List<Booking> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchBookings(int employeeId, {String? startDate, String? endDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _bookingService.fetchBookings(employeeId: employeeId, startDate: startDate, endDate: endDate);

    _isLoading = false;
    if (result['success']) {
      _bookings = result['data'];
      _error = null;
    } else {
      _error = result['error'];
    }
    notifyListeners();
  }
}

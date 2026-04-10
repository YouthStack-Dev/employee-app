import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/booking_model.dart';
import 'api_service.dart';

class BookingService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> fetchBookings({required int employeeId, String? startDate, String? endDate}) async {
    try {
      final now = DateTime.now();
      // Use provided dates or default to current week logic
      final start = startDate ?? DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final end = endDate ?? DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));

      final response = await _apiService.dio.get(
        ApiConstants.bookings,
        queryParameters: {
          'employee_id': employeeId,
          'start_date': start,
          'end_date': end,
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        final rawData = response.data['data'];
        final List<dynamic> data = (rawData is List) ? rawData : [];
        final bookings = data.map((json) => Booking.fromJson(json)).toList();
        return {
          'success': true, 
          'data': bookings,
          'meta': response.data['meta'] // Pass meta data if available
        };
      }
      return {'success': false, 'error': 'Failed to fetch bookings'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to fetch bookings';
      
      // Specifically handle the 500 error we know exists
      if (e.response?.statusCode == 500) {
        final data = e.response?.data;
        if (data != null && data['detail'] != null && data['detail']['message'] != null) {
             errorMessage = 'Server Error: ${data['detail']['message']}';
             if (data['detail']['details'] != null) {
                 errorMessage += '\nDetails: ${data['detail']['details']['original_error']}';
             }
        } else {
             errorMessage = 'Internal Server Error (500)';
        }
      } else if (e.response?.data != null) {
         // General error parsing
         final data = e.response!.data;
         if (data['detail'] is String) errorMessage = data['detail'];
      }
      
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBooking(int bookingId, Map<String, dynamic> updateData) async {
    try {
      // Use /api/v1/bookings/{id}
      final response = await _apiService.dio.put('${ApiConstants.bookingOperations}/$bookingId', data: updateData);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
         return {
           'success': true,
           'data': Booking.fromJson(response.data['data']),
           'message': response.data['message'] ?? 'Booking updated successfully'
         };
      }
      return {'success': false, 'error': 'Failed to update booking'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  Future<Map<String, dynamic>> createBooking({
    required String tenantId,
    required int employeeId,
    required List<String> bookingDates,
    required int shiftId,
  }) async {
    try {
      final response = await _apiService.dio.post(
        ApiConstants.createBooking,
        data: {
            "tenant_id": tenantId,
            "employee_id": employeeId,
            "booking_dates": bookingDates,
            "shift_id": shiftId
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('CREATE BOOKING RESPONSE RAW: ${response.data}'); // DEBUG LOG
        
        dynamic bookingData = response.data;
        dynamic bookingId;
        
        // Defensive parsing tree
        if (bookingData is Map) {
            // Case 1: { "data": { "booking_id": 123 } } OR { "data": [ ... ] }
            if (bookingData.containsKey('data')) {
                final innerData = bookingData['data'];
                if (innerData is Map) {
                    bookingId = innerData['booking_id'];
                } else if (innerData is List && innerData.isNotEmpty) {
                    final firstItem = innerData[0];
                    if (firstItem is Map) {
                        bookingId = firstItem['booking_id'];
                    }
                }
            } 
            // Case 2: { "booking_id": 123 }
            else if (bookingData.containsKey('booking_id')) {
                bookingId = bookingData['booking_id'];
            }
        } else if (bookingData is List && bookingData.isNotEmpty) {
            // Case 3: [ { "booking_id": 123 } ]
            final firstItem = bookingData[0];
            if (firstItem is Map) {
                bookingId = firstItem['booking_id'];
            }
        }
        
        return {
            'success': true, 
            'bookingId': bookingId,
            'message': 'Booking created successfully'
        };
      }
      return {'success': false, 'error': 'Failed to create booking'};
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
          dynamic data = e.response!.data;
          print('BOOKING ERROR RAW: $data'); // DEBUG LOG
          
          String error = 'Failed to create booking';
          
          if (data is Map) {
               if (data['detail'] != null) {
                  if (data['detail'] is String) {
                      error = data['detail'];
                  } else if (data['detail'] is Map && data['detail']['message'] != null) {
                      error = data['detail']['message'];
                  }
               } else if (data['message'] != null) {
                   error = data['message'];
               }
          } else if (data is List) {
              error = data.toString(); // Or extract valid error from list
          }
           return {'success': false, 'error': error};
      }
      return {'success': false, 'error': e.toString()}; 
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
      try {
          // Use /api/v1/bookings/cancel/{id}
          final response = await _apiService.dio.patch('${ApiConstants.bookingOperations}/cancel/$bookingId');
          if (response.statusCode == 200 || response.statusCode == 201) {
              return {'success': true, 'message': 'Booking cancelled successfully'};
          }
          return {'success': false, 'error': 'Failed to cancel booking'};
      } on DioException catch (e) {
          return {'success': false, 'error': _parseError(e)};
      } catch (e) {
          return {'success': false, 'error': e.toString()};
      }
  }

  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    try {
      // Use /api/v1/bookings/{id}
      final response = await _apiService.dio.get('${ApiConstants.bookingOperations}/$bookingId');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {'success': true, 'data': Booking.fromJson(data)};
      }
      return {'success': false, 'error': 'Failed to fetch booking details'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data['detail'] is String) return data['detail'];
      if (data['detail'] is Map && data['detail']['message'] != null) return data['detail']['message'];
      if (data['message'] != null) return data['message'];
    }
    return e.message ?? 'Unknown network error';
  }
}

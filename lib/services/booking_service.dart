import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/booking_model.dart';
import 'api_service.dart';

class BookingService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> fetchBookings({
    required int employeeId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final now = DateTime.now();
      // Use provided dates or default to current week logic
      final start =
          startDate ??
          DateFormat(
            'yyyy-MM-dd',
          ).format(now.subtract(const Duration(days: 1)));
      final end =
          endDate ??
          DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));

      print(
        '📋 FETCH BOOKINGS REQUEST: employee_id=$employeeId, start=$start, end=$end',
      );

      final response = await _apiService.dio.get(
        ApiConstants.bookings,
        queryParameters: {
          'employee_id': employeeId,
          'start_date': start,
          'end_date': end,
          'limit': 50,
        },
      );

      print('📋 FETCH BOOKINGS RESPONSE STATUS: ${response.statusCode}');
      print('📋 FETCH BOOKINGS RAW DATA TYPE: ${response.data.runtimeType}');
      print('📋 FETCH BOOKINGS RAW DATA: ${response.data}');

      if (response.statusCode == 200) {
        // Safely extract the data — the API may return different shapes per tenant
        final responseData = response.data;
        List<dynamic> bookingsList = [];

        if (responseData is Map<String, dynamic>) {
          final rawData = responseData['data'];
          if (rawData is List) {
            bookingsList = rawData;
          } else if (rawData is Map<String, dynamic>) {
            // Handle paginated response: { data: { bookings: [...] } }
            if (rawData['bookings'] is List) {
              bookingsList = rawData['bookings'];
            } else if (rawData['results'] is List) {
              bookingsList = rawData['results'];
            }
          }
        } else if (responseData is List) {
          bookingsList = responseData;
        }

        print('📋 PARSED BOOKINGS COUNT: ${bookingsList.length}');
        if (bookingsList.isNotEmpty) {
          print('📋 FIRST BOOKING: ${bookingsList[0]}');
        }

        final bookings = bookingsList.map((json) {
          if (json is Map<String, dynamic>) {
            return Booking.fromJson(json);
          }
          return Booking.fromJson(Map<String, dynamic>.from(json));
        }).toList();

        return {
          'success': true,
          'data': bookings,
          'meta': (responseData is Map) ? responseData['meta'] : null,
        };
      }
      return {'success': false, 'error': 'Failed to fetch bookings'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to fetch bookings'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBooking(
    int bookingId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      // Use /api/v1/bookings/{id}
      final response = await _apiService.dio.put(
        '${ApiConstants.bookingOperations}/$bookingId',
        data: updateData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'data': Booking.fromJson(response.data['data']),
          'message': response.data['message'] ?? 'Booking updated successfully',
        };
      }
      return {'success': false, 'error': 'Failed to update booking'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to update booking'),
      };
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
          "shift_id": shiftId,
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
          'message': 'Booking created successfully',
        };
      }
      return {'success': false, 'error': 'Failed to create booking'};
    } on DioException catch (e) {
      if (e.response?.data != null) {
        print('BOOKING ERROR RAW: ${e.response!.data}'); // DEBUG LOG
      }
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to create booking'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    try {
      // Use /api/v1/bookings/cancel/{id}
      final response = await _apiService.dio.patch(
        '${ApiConstants.bookingOperations}/cancel/$bookingId',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Booking cancelled successfully'};
      }
      return {'success': false, 'error': 'Failed to cancel booking'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to cancel booking'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    try {
      // Use /api/v1/bookings/{id}
      final response = await _apiService.dio.get(
        '${ApiConstants.bookingOperations}/$bookingId',
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {'success': true, 'data': Booking.fromJson(data)};
      }
      return {'success': false, 'error': 'Failed to fetch booking details'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to fetch booking details'),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String _parseError(
    DioException e, {
    String fallback = 'Unknown network error',
  }) {
    final parsed = _parseErrorData(e.response?.data);
    if (parsed != null && parsed.isNotEmpty) return parsed;
    return e.message ?? fallback;
  }

  String? _parseErrorData(dynamic data) {
    if (data == null) return null;
    if (data is String && data.isNotEmpty) return data;
    if (data is List && data.isNotEmpty) return data.toString();
    if (data is! Map) return null;

    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is Map) {
      final message = detail['message']?.toString();
      final errorCode =
          detail['error_code']?.toString() ?? detail['code']?.toString();
      if (message != null && message.isNotEmpty) {
        return errorCode == null ? message : '$message ($errorCode)';
      }
      if (errorCode != null && errorCode.isNotEmpty) return errorCode;
    }

    final message = data['message']?.toString();
    final errorCode =
        data['error_code']?.toString() ?? data['code']?.toString();
    if (message != null && message.isNotEmpty) {
      return errorCode == null ? message : '$message ($errorCode)';
    }
    if (errorCode != null && errorCode.isNotEmpty) return errorCode;
    return null;
  }
}

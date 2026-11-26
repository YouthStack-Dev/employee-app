import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../models/booking_model.dart';
import '../models/shift_model.dart';
import 'api_service.dart';
import 'shift_service.dart';

class BookingService {
  BookingService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

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
          } else           if (rawData is Map<String, dynamic>) {
            // Handle documented paginated response:
            // { data: { items: [...], total, skip, limit } }
            if (rawData['items'] is List) {
              bookingsList = rawData['items'];
            } else if (rawData['bookings'] is List) {
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

        if (bookings.any((b) => b.logType == null)) {
          final shiftLogType = await _loadShiftLogTypeMap();
          _enrichLogType(bookings, shiftLogType);
        }

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
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> updateBooking(
    int bookingId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      // Use /api/v1/app/bookings/{id}
      final response = await _apiService.dio.put(
        '${ApiConstants.bookingOperations}/$bookingId',
        data: updateData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        if (data == null || data is! Map) {
          return {'success': false, 'error': 'Empty response from server'};
        }
        return {
          'success': true,
          'data': Booking.fromJson(Map<String, dynamic>.from(data)),
          'message': response.data['message'] ?? 'Booking updated successfully',
        };
      }
      return {
        'success': false,
        'error': AppErrorMessages.bookingUpdateFailed,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(
          e,
          feature: 'bookingUpdate',
          fallback: AppErrorMessages.bookingUpdateFailed,
        ),
      };
    } catch (e) {
      return {'success': false, 'error': AppErrorMessages.bookingUpdateFailed};
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
          "pickup_type": "regular",
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('CREATE BOOKING RESPONSE RAW: ${response.data}'); // DEBUG LOG

        final bookingData = response.data;
        dynamic innerData = bookingData is Map ? bookingData['data'] : null;

        // Documented shape: data: { created: [...], skipped: [...] }
        final List created =
            (innerData is Map && innerData['created'] is List) ? innerData['created'] : [];
        final List skipped =
            (innerData is Map && innerData['skipped'] is List) ? innerData['skipped'] : [];

        dynamic bookingId;
        if (created.isNotEmpty && created.first is Map) {
          bookingId = created.first['booking_id'];
        }

        // Defensive parsing tree for tenants that return other shapes
        if (bookingId == null) {
          if (bookingData is Map) {
            if (bookingData.containsKey('data')) {
              final nested = bookingData['data'];
              if (nested is Map) {
                bookingId = nested['booking_id'];
              } else if (nested is List && nested.isNotEmpty && nested.first is Map) {
                bookingId = nested.first['booking_id'];
              }
            } else if (bookingData.containsKey('booking_id')) {
              bookingId = bookingData['booking_id'];
            }
          } else if (bookingData is List && bookingData.isNotEmpty && bookingData.first is Map) {
            bookingId = bookingData.first['booking_id'];
          }
        }

        final createdCount = created.isNotEmpty ? created.length : bookingDates.length;

        String message;
        if (bookingData is Map && bookingData['message'] != null) {
          message = bookingData['message'].toString();
        } else if (createdCount >= bookingDates.length) {
          message = bookingDates.length == 1
              ? 'Booking created successfully'
              : '${bookingDates.length} booking(s) created successfully';
        } else {
          message =
              '$createdCount of ${bookingDates.length} date(s) booked. ${bookingDates.length - createdCount} date(s) were skipped.';
        }

        return {
          'success': true,
          'bookingId': bookingId,
          'message': message,
          'createdCount': createdCount,
          'requestedCount': bookingDates.length,
          'skipped': skipped,
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
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  /// Books login + logout legs in a single atomic call (round-trip style).
  /// Both leg objects are always present. A disabled leg reuses the enabled
  /// leg's real shift_id because the backend schema requires an int for both.
  Future<Map<String, dynamic>> createRoundTripBooking({
    required String tenantId,
    required int employeeId,
    required List<String> bookingDates,
    Shift? loginShift,
    Shift? logoutShift,
    bool logoutNextDay = false,
    String? loginPickup,
    String? loginDropoff,
    String? logoutPickup,
    String? logoutDropoff,
  }) async {
    final loginShiftId = loginShift?.shiftId;
    final logoutShiftId = logoutShift?.shiftId;
    final hasLogin = loginShiftId != null;
    final hasLogout = logoutShiftId != null;

    if (!hasLogin && !hasLogout) {
      return {
        'success': false,
        'error': 'Please select at least one journey (Login or Logout).',
      };
    }

    try {
      final body = <String, dynamic>{
        'tenant_id': tenantId,
        'employee_id': employeeId,
        'booking_dates': bookingDates,
        'booking_type': 'regular',
        'login': {
          'enabled': hasLogin,
          'shift_id': loginShiftId ?? logoutShiftId,
          if (hasLogin && loginPickup != null) 'pickup': loginPickup,
          if (hasLogin && loginDropoff != null) 'dropoff': loginDropoff,
          if (hasLogin) 'pickup_type': 'regular',
        },
        'logout': {
          'enabled': hasLogout,
          'shift_id': logoutShiftId ?? loginShiftId,
          if (hasLogout && logoutPickup != null) 'pickup': logoutPickup,
          if (hasLogout && logoutDropoff != null) 'dropoff': logoutDropoff,
          if (hasLogout) 'pickup_type': 'regular',
          if (hasLogout) 'next_day': logoutNextDay,
        },
      };

      final response = await _apiService.dio.post(
        ApiConstants.createRoundTripBooking,
        data: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('ROUND-TRIP BOOKING RESPONSE RAW: ${response.data}'); // DEBUG LOG

        final bookingData = response.data;
        final innerData = bookingData is Map ? bookingData['data'] : null;

        final createdRows = <Map<String, dynamic>>[];
        if (innerData is Map && innerData['created'] is List) {
          for (final item in (innerData['created'] as List)) {
            if (item is Map) {
              createdRows.add({
                'bookingId': item['booking_id'],
                'date': item['date']?.toString(),
                'type': item['type']?.toString(),
              });
            }
          }
        }

        final skippedRows = <Map<String, dynamic>>[];
        if (innerData is Map && innerData['skipped'] is List) {
          for (final item in (innerData['skipped'] as List)) {
            if (item is Map) skippedRows.add(Map<String, dynamic>.from(item));
          }
        }

        final pairId = (innerData is Map ? innerData['booking_id'] : null) ??
            (createdRows.isNotEmpty ? createdRows.first['bookingId'] : null);
        final dynamic loginBookingId =
            innerData is Map ? innerData['login_booking_id'] : null;
        final dynamic logoutBookingId =
            innerData is Map ? innerData['logout_booking_id'] : null;

        final actualCount = createdRows.length;
        final enabledLegs = (hasLogin ? 1 : 0) + (hasLogout ? 1 : 0);
        final requestedRows = enabledLegs * bookingDates.length;
        final responseDates = createdRows
            .map((row) => row['date'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        String message;
        if (actualCount == 0) {
          message = bookingData is Map && bookingData['message'] != null
              ? bookingData['message'].toString()
              : 'No bookings were created.';
        } else if (actualCount == 1) {
          final row = createdRows.first;
          final typeLabel = row['type'] == 'login'
              ? 'Login'
              : row['type'] == 'logout'
                  ? 'Logout'
                  : 'Booking';
          final date = row['date'];
          message = date != null
              ? '$typeLabel booking created successfully for $date.'
              : '$typeLabel booking created successfully.';
        } else {
          message = responseDates.isEmpty
              ? '$actualCount bookings created successfully.'
              : '$actualCount bookings created successfully for ${responseDates.join(', ')}.';
        }
        if (skippedRows.isNotEmpty) {
          message += ' ${skippedRows.length} booking(s) were skipped.';
        }

        return {
          'success': true,
          'bookingId': pairId,
          'loginBookingId': loginBookingId,
          'logoutBookingId': logoutBookingId,
          'message': message,
          'createdCount': actualCount,
          'requestedCount': requestedRows,
          'created': createdRows,
          'skipped': skippedRows,
        };
      }
      return {'success': false, 'error': 'Failed to create schedule'};
    } on DioException catch (e) {
      if (e.response?.data != null) {
        print('ROUND-TRIP BOOKING ERROR RAW: ${e.response!.data}'); // DEBUG LOG
      }
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to create schedule'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> cancelBooking(int bookingId, {String? reason}) async {
    try {
      // Use /api/v1/app/bookings/cancel/{id} — optional {reason} body per docs
      final response = await _apiService.dio.patch(
        '${ApiConstants.bookingOperations}/cancel/$bookingId',
        data: (reason != null && reason.trim().isNotEmpty) ? {'reason': reason.trim()} : null,
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
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  Future<Map<int, String>> _loadShiftLogTypeMap() async {
    try {
      final result = await ShiftService().fetchShifts();
      if (result['success']) {
        final all = (result['shifts']['all'] as List).cast<Shift>();
        return {for (final s in all) if (s.shiftId != null) s.shiftId!: s.logType ?? 'IN'};
      }
    } catch (_) {}
    return {};
  }

  void _enrichLogType(List<Booking> bookings, Map<int, String> shiftLogType) {
    for (int i = 0; i < bookings.length; i++) {
      final b = bookings[i];
      if (b.logType == null && b.shiftId != null && shiftLogType.containsKey(b.shiftId!)) {
        bookings[i] = b.copyWith(logType: shiftLogType[b.shiftId!]);
      }
    }
  }

  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    try {
      // Use /api/v1/app/bookings/{id}
      final response = await _apiService.dio.get(
        '${ApiConstants.bookingOperations}/$bookingId',
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data == null || data is! Map) {
          return {'success': false, 'error': 'Empty response from server'};
        }
        final booking = Booking.fromJson(Map<String, dynamic>.from(data));

        if (booking.logType == null && booking.shiftId != null) {
          final shiftLogType = await _loadShiftLogTypeMap();
          final enriched = [booking];
          _enrichLogType(enriched, shiftLogType);
          return {'success': true, 'data': enriched.first};
        }

        return {'success': true, 'data': booking};
      }
      return {'success': false, 'error': 'Failed to fetch booking details'};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _parseError(e, fallback: 'Failed to fetch booking details'),
      };
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }

  String _parseError(
    DioException e, {
    String feature = 'booking',
    String fallback = 'Something went wrong. Please try again.',
  }) {
    return ApiError.resolve(
      e,
      feature: feature,
      fallback: fallback,
    );
  }
}

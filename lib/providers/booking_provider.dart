import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/route_service.dart';
import 'auth_provider.dart';
import '../services/overlay_service.dart';
import '../services/background_tracking_service.dart';
import '../services/session_service.dart';
import '../services/navigation_service.dart';

class BookingProvider extends ChangeNotifier {
  final RouteService _routeService = RouteService();
  
  List<dynamic> _routes = [];
  List<dynamic> _bookings = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get routes => _routes;
  List<dynamic> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearData() {
    _routes = [];
    _bookings = [];
    _error = null;
    notifyListeners();
  }

  Future<void> fetchTrips({String status = 'upcoming', bool showLoading = true, bool skipSafetyCatch = false}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _routeService.getDriverTrips(statusFilter: status);
      if (result['success'] == true) {
        _routes = result['routes'] ?? [];
        debugPrint('🌐 [API Response] Routes Payload count: ${_routes.length}');
        for (final r in _routes) {
          final rStops = r['stops'] as List? ?? [];
          debugPrint('🌐 [API Response] Route #${r['route_id']} status: ${r['status']} | Stops count: ${rStops.length}');
          for (final stop in rStops) {
            debugPrint('👤 [Stop Data] Booking ID: ${stop['booking_id']} | Employee: ${stop['employee_name']} | Status: ${stop['status']} | Keys in stop: ${stop.keys.toList()}');
          }
        }
        
        // Safety catch: If backend says there are no ongoing trips, 
        // ensure background tracking and overlays are stopped to prevent ghost notifications.
        // Skip this when called immediately after duty start (skipSafetyCatch=true)
        // because the backend may not have committed the new route yet (read-after-write lag),
        // and clearing the route would orphan the Kotlin uploader with the previous route ID.
        if (status == 'ongoing' && _routes.isEmpty && !skipSafetyCatch) {
          await SessionService().clearActiveRoute();
          await SessionService().setTrackingEnabled(false);
          await BackgroundTrackingService().stopBackgroundTracking();
          await OverlayService().hideOverlay();
        }
      } else {
        final errorCode = result['errorCode']?.toString() ?? '';
        // 401/403 = session invalid — force logout immediately
        if (errorCode == 'UNAUTHORIZED' || errorCode == 'FORBIDDEN') {
          await SessionService().clearSession();
          NavigationService.navigateTo('/login');
          return;
        }
        if (showLoading) _error = result['error'];
      }
    } catch (e) {
      if (showLoading) _error = 'Unable to load routes. Please try again.';
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchBookings(BuildContext context, {int skip = 0, int limit = 100}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      // Try to find employee_id in various places
      final employeeId = user?['employee_id'] ?? 
                         user?['user']?['employee_id'] ?? 
                         user?['employee']?['id'];

      final params = {
        'skip': skip,
        'limit': limit,
      };
      
      if (employeeId != null) {
        params['employee_id'] = employeeId;
      }
      
      final result = await _routeService.getEmployeeBookings(params: params);
      
      if (result['success'] == true) {
        _bookings = result['bookings'] ?? [];
      } else {
        _error = result['error'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelBooking(BuildContext context, String bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.cancelBooking(bookingId);
      if (result['success'] == true) {
        if (!context.mounted) return false;
        await fetchBookings(context);
        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startDuty(String routeId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.startDuty(routeId);
      if (result['success'] == true) {
        // ── CRITICAL: Persist route ID and start Kotlin tracking FIRST ──
        // This must happen before fetchTrips() because fetchTrips contains a
        // safety catch that clears active_route_id when the backend returns
        // no ongoing trips (e.g., read-after-write lag). If we clear the route
        // after just writing it, the Kotlin uploader falls back to the previous
        // route ID that was already queued in SQLite.
        await SessionService().saveActiveRoute(routeId);
        await SessionService().setTrackingEnabled(true);

        final token = await SessionService().getAccessToken() ?? '';
        
        final userData = await SessionService().getUserData();
        final driverId = userData?['driver_id'] ?? userData?['user']?['driver']?['driver_id'] ?? userData?['driver']?['driver_id'];
        final tenantId = userData?['tenant_id'] ?? userData?['account']?['tenant_id'] ?? userData?['user']?['tenant_id'] ?? userData?['user']?['tenant']?['tenant_id'];
        final vendorId = userData?['vendor_id'] ?? userData?['account']?['vendor_id'] ?? userData?['user']?['driver']?['vendor_id'];

        await BackgroundTrackingService().startBackgroundTracking(
          routeId: routeId,
          accessToken: token,
          driverId: driverId?.toString(),
          tenantId: tenantId?.toString(),
          vendorId: vendorId?.toString(),
        );

        // Now refresh routes — skip safety catch because route is already
        // persisted and Kotlin is already tracking it.
        await fetchTrips(status: 'ongoing', skipSafetyCatch: true);
        
        // Show overlay when duty starts
        await OverlayService().showOverlay();

        return true;
      } else {
        _error = result['error'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> startTrip(String routeId, String bookingId, String? otp, double lat, double lng) async {
    // Generate a stable idempotency key per tap.
    // Format: pickup-{routeId}-{bookingId}-{epochSeconds}
    // Retrying from a network error with the same key is safe — the backend
    // will return the already-recorded stop event instead of creating a duplicate.
    final idempotencyKey =
        'pickup-$routeId-$bookingId-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final deviceTimestamp = DateTime.now().toUtc().toIso8601String();

    return _performAction(() => _routeService.startTrip(
      routeId: routeId,
      bookingId: bookingId,
      otp: otp,
      latitude: lat,
      longitude: lng,
      idempotencyKey: idempotencyKey,
      deviceTimestamp: deviceTimestamp,
    ));
  }

  Future<Map<String, dynamic>> dropTrip(String routeId, String bookingId, String? otp, double lat, double lng) async {
    // Generate a stable idempotency key per tap.
    // Format: drop-{routeId}-{bookingId}-{epochSeconds}
    final idempotencyKey =
        'drop-$routeId-$bookingId-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final deviceTimestamp = DateTime.now().toUtc().toIso8601String();

    return _performAction(() => _routeService.dropTrip(
      routeId: routeId,
      bookingId: bookingId,
      otp: otp,
      latitude: lat,
      longitude: lng,
      idempotencyKey: idempotencyKey,
      deviceTimestamp: deviceTimestamp,
    ));
  }

  /// Board the escort on an ONGOING route before any employee pickup.
  /// Calls POST /driver/escort/board. [code] is optional — omitted for
  /// `off` mode, required for `universal` / `unique` modes.
  Future<Map<String, dynamic>> escortBoard(String routeId, {String? code}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _routeService.escortBoard(routeId: routeId, code: code);
      if (result['success'] == true) {
        await fetchTrips(status: 'ongoing'); // Refresh so escort_boarded flag updates
      } else {
        _error = result['error'];
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> markNoShow(String routeId, String bookingId, String? reason) async {
    return _performAction(() => _routeService.markNoShow(
      routeId: routeId,
      bookingId: bookingId,
      reason: reason
    ));
  }

  Future<Map<String, dynamic>> endDuty(String routeId, String? reason, {bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final result = await _routeService.endDuty(routeId, reason);
      
      final bool success = result['success'] == true;
      final errorMsg = result['error']?.toString().toLowerCase() ?? '';
      final errorCode = result['errorCode']?.toString().toUpperCase() ?? '';
      
      final bool alreadyEnded = !success && (
        errorMsg.contains('already ended') || 
        errorMsg.contains('not active') || 
        errorMsg.contains('no active duty') ||
        errorCode.contains('ALREADY_ENDED') || 
        errorCode.contains('NOT_ACTIVE') ||
        errorCode.contains('DUTY_ENDED')
      );

      if (success || alreadyEnded) {
        await OverlayService().hideOverlay();
        
        // Clear active route when duty ends (or fails because it already ended)
        await SessionService().clearActiveRoute();
        await SessionService().setTrackingEnabled(false);
        
        // Stop Kotlin background service — trip is over
        await BackgroundTrackingService().stopBackgroundTracking();
        
        Map<String, dynamic>? summaryData;
        try {
          // Wait 2 seconds for backend to finish calculations
          await Future.delayed(const Duration(seconds: 2));
          final completedTrips = await _routeService.getDriverTrips(statusFilter: 'completed');
          if (completedTrips['success'] == true && completedTrips['routes'] is List && completedTrips['routes'].isNotEmpty) {
            final routes = completedTrips['routes'] as List;
            final endedRoute = routes.firstWhere(
              (r) => r['route_id']?.toString() == routeId,
              orElse: () => routes.first,
            );
            summaryData = {
              'actual_total_distance': endedRoute['actual_distance_km'] ?? endedRoute['actual_total_distance'],
              'actual_total_time': endedRoute['actual_total_time'],
              'estimated_total_distance': endedRoute['estimated_distance_km'] ?? endedRoute['estimated_total_distance'],
              'estimated_total_time': endedRoute['estimated_total_time'],
              'route_code': endedRoute['route_code'] ?? endedRoute['route_id']?.toString() ?? routeId,
              'stops_count': endedRoute['stops'] is List ? (endedRoute['stops'] as List).length : 0,
              'boarded_count': endedRoute['stops'] is List
                  ? (endedRoute['stops'] as List).where((s) => s['status'] == 'Completed').length
                  : 0,
            };
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching completed duty summary: $e');
        }

        // Refresh to upcoming
        await fetchTrips(status: 'upcoming', showLoading: showLoading);

        final Map<String, dynamic> response = {'success': true};
        if (summaryData != null) response['summary'] = summaryData;
        return response;
      } else {
        if (showLoading) _error = result['error'];
      }
      return result;
    } finally {
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> _performAction(Future<Map<String, dynamic>> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await action();
      if (result['success'] == true) {
        await fetchTrips(status: 'ongoing'); // Refresh
      } else {
        _error = result['error'];
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

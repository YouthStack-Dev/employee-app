/// Centralized error-code-to-UX-message mapper.
///
/// Instead of showing raw backend messages, we translate every known error code
/// into friendly, actionable copy that helps the employee understand what happened
/// and what to do next.
class AppErrorMessages {
  AppErrorMessages._();

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> auth = {
    // Login
    'ACCOUNT_INACTIVE':
        'Your account is currently inactive. Please contact your HR or transport admin to reactivate it.',
    'APP_ACCESS_DISABLED':
        'App access has been disabled for your account. Please reach out to your transport coordinator.',
    'ACCOUNT_NOT_FOUND':
        'We couldn\'t find an account with these details. Please check your email or phone number and try again.',
    'NO_TENANT_ACCESS':
        'Your organization access is currently inactive. Please contact your admin.',

    // OTP
    'OTP_EXPIRED':
        'Your OTP has expired. Please request a new one.',
    'INVALID_OTP':
        'That OTP doesn\'t match. Please check and enter again.',
    'MAX_OTP_ATTEMPTS':
        'You\'ve exceeded the maximum attempts. Please request a new OTP after 1 minute.',
    'OTP_STORAGE_FAILED':
        'We\'re having trouble sending the OTP right now. Please try again in a moment.',

    // Tenant selection
    'PRE_AUTH_TOKEN_REQUIRED':
        'Your verification session is missing. Please start the login process again.',
    'PRE_AUTH_TOKEN_INVALID':
        'Your verification has expired. Please start the login process again.',
    'TENANT_ACCESS_DENIED':
        'You don\'t have access to this organization. Please select a different one or contact your admin.',
    'ALREADY_IN_TENANT':
        'You\'re already logged into this organization.',

    // Token
    'TOKEN_EXPIRED':
        'Your session has expired. Please log in again.',
    'INVALID_TOKEN':
        'Your session is invalid. Please log in again.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKINGS
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> booking = {
    'TENANT_ID_REQUIRED':
        'Something went wrong with your session. Please log out and log in again.',
    'TENANT_FORBIDDEN':
        'You don\'t have access to book for this organization.',
    'EMPLOYEE_NOT_FOUND':
        'Your employee profile could not be found. Please contact your admin.',
    'BOOKING_OWNERSHIP_FORBIDDEN':
        'You can only manage your own bookings.',
    'EMPLOYEE_APP_INACTIVE':
        'Your app access has been disabled. Please contact your transport coordinator.',
    'SHIFT_NOT_FOUND':
        'This shift is no longer available. Please select a different one.',
    'SHIFT_INACTIVE':
        'This shift has been deactivated. Please choose another shift.',
    'SHIFT_GENDER_MISMATCH':
        'This shift is not available for your profile. Please select another shift.',
    'WRONG_SHIFT_LOG_TYPE':
        'Please select a valid shift for your journey.',
    'WEEKOFF_DAY':
        'You can\'t book on your designated day off. Please select a working day.',
    'ADHOC_BOOKING_DISABLED':
        'Ad-hoc bookings are not enabled for your team. Please contact your admin if you need a one-time ride.',
    'BOOKING_CUTOFF':
        'Your selected shift is outside the permitted booking time.',
    'PAST_SHIFT_TIME':
        'This shift has already started today. Please book for tomorrow or a future date.',
    'INVALID_DATE':
        'Please select a valid future travel date.',
    'BOOKING_FROZEN':
        'Bookings are currently unavailable for the selected date.',
    'BOOKING_TOO_FAR_AHEAD':
        'The selected date is outside the allowed advance-booking period.',
    'MAX_ACTIVE_BOOKINGS_REACHED':
        'You have reached the maximum number of active bookings.',
    'ALREADY_BOOKED':
        'You have already booked this shift for the selected date.',
    'NEXT_DAY_WEEKOFF':
        'Your next-day Logout date falls on a weekly off.',
    'HOLIDAY_BLOCKED':
        'Booking is unavailable because the selected date is a holiday.',
    'NOTHING_TO_BOOK':
        'Please select at least one journey (Login or Logout).',
    'NO_NODAL_ASSIGNMENT':
        'You don\'t have a pickup hub assigned yet. Please contact your transport coordinator.',
    'NODAL_POINT_INACTIVE':
        'Your assigned pickup hub is currently inactive. Please contact your admin.',
    'MISSING_FILTER':
        'Something went wrong loading your bookings. Please try again.',
    'UNAUTHORIZED_BOOKING_ACCESS':
        'You can only view your own bookings.',
    'BOOKING_NOT_FOUND':
        'This booking could not be found. It may have been removed.',
    'INVALID_BOOKING_STATUS':
        'This booking can\'t be modified in its current state.',
    'INVALID_REBOOK_STATUS':
        'Only cancelled bookings can be rebooked.',
    'DUPLICATE_BOOKING':
        'You already have a booking for this date and shift combination.',
    'CANCEL_REASON_REQUIRED':
        'Please provide a reason for cancellation.',
    'PAST_BOOKING':
        'Past bookings cannot be cancelled.',
    'BOOKING_NOT_CANCELLABLE':
        'This booking cannot be cancelled in its current status. It may already be in progress.',
    'CANCEL_CUTOFF':
        'Booking cancellation time has expired. Please contact your administrator.',
  };

  static const Map<String, String> bookingUpdate = {
    'INSUFFICIENT_PERMISSIONS':
        'You don\'t have permission to modify this booking. Please contact your transport administrator.',
    'BOOKING_NOT_FOUND':
        'This booking is no longer available. Refresh your bookings and try again.',
    'HOLIDAY_OVERRIDE_MOBILE_FORBIDDEN':
        'Holiday booking overrides aren\'t available in the app. Please contact your transport administrator.',
    'HOLIDAY_OVERRIDE_FORBIDDEN':
        'You don\'t have permission to make a holiday booking change.',
    'HOLIDAY_OVERRIDE_REASON_REQUIRED':
        'Please provide a reason for the holiday booking change.',
    'INVALID_BOOKING_STATUS':
        'This booking can no longer be modified because it has already been processed.',
    'INVALID_REBOOK_STATUS':
        'This booking can no longer be rebooked because it is no longer cancelled. Refresh the details to see its current status.',
    'SHIFT_NOT_FOUND':
        'The selected shift is no longer available. Please choose another shift.',
    'SHIFT_INACTIVE':
        'The selected shift has been deactivated. Please choose another shift.',
    'EMPLOYEE_NOT_FOUND':
        'Your employee profile could not be found. Please contact your transport administrator.',
    'EMPLOYEE_APP_INACTIVE':
        'Your app access has been disabled. Please contact your transport administrator.',
    'SHIFT_GENDER_MISMATCH':
        'This shift is not available for your profile. Please choose another shift.',
    'INVALID_DATE':
        'Please select a valid future travel date.',
    'HOLIDAY_BLOCKED':
        'The selected date is a holiday and cannot be used for this booking change.',
    'WEEKOFF_DAY':
        'The selected date is your weekly off. Please choose a working day.',
    'ADHOC_BOOKING_DISABLED':
        'Ad-hoc booking changes are not enabled for your organization.',
    'MEDICAL_EMERGENCY_BOOKING_DISABLED':
        'Medical emergency booking changes are not enabled for your organization.',
    'SHIFT_TIME_MISSING':
        'The selected shift has no configured time. Please choose another shift.',
    'BOOKING_CUTOFF':
        'Booking modification time has expired. Please contact your administrator.',
    'PAST_SHIFT_TIME':
        'This shift has already started. The booking can no longer be modified. Please choose a future shift.',
    'DUPLICATE_BOOKING':
        'You already have an active booking for this shift and date. Please choose a different shift or date.',
    'NO_NODAL_ASSIGNMENT':
        'You don\'t have a pickup hub assigned yet. Please contact your transport coordinator.',
    'INVALID_BOOKING_STATUS_TRANSITION':
        'This booking cannot move to the requested status. Please refresh and try again.',
    'TRANSITION_SOURCE_NOT_ALLOWED':
        'This booking change is not allowed from the app. Please contact your transport administrator.',
    'INTERNAL_SERVER_ERROR':
        'Something went wrong on our end. Please try again in a moment.',
  };

  static const Map<String, String> bookingUpdateDefensive = {
    'LOCATION_EDIT_DISABLED':
        'Location changes are disabled by your transport administrator.',
    'BOOKING_FROZEN':
        'Booking modifications are temporarily disabled by your transport administrator.',
    'BOOKING_ALREADY_ASSIGNED':
        'Trip already generated. Please contact administrator to modify this booking.',
    'BOOKING_ALREADY_ACTIVE':
        'Your journey is already active. This booking can no longer be modified.',
    'BOOKING_TOO_FAR_AHEAD':
        'The selected date is outside the allowed booking period.',
    'MAX_ACTIVE_BOOKINGS_REACHED':
        'You already have the maximum number of active bookings.',
  };

  static const Map<String, String> bookingUpdateStatus = {
    'SCHEDULED':
        'Trip already generated. Please contact administrator to modify this booking.',
    'ONGOING':
        'Your journey has already started. This booking can no longer be modified.',
    'COMPLETED':
        'This journey has already been completed. The booking cannot be modified.',
    'NO_SHOW':
        'This booking was marked as a no-show and can no longer be modified.',
    'EXPIRED':
        'This booking has expired and can no longer be modified.',
    'CANCELLED':
        'This booking is cancelled. Please use rebook instead of update.',
    'REQUEST':
        'This booking is still being processed. Please refresh and try again.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // SHIFTS
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> shift = {
    'FORBIDDEN':
        'You don\'t have access to view shifts.',
    'TENANT_ID_REQUIRED':
        'Something went wrong. Please log out and log in again.',
    'TENANT_NOT_FOUND':
        'Your organization could not be found. Please contact support.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // WEEKOFF
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> weekoff = {
    'TENANT_FORBIDDEN':
        'Unable to load your schedule settings. Please try again.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // REVIEWS
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> review = {
    'BOOKING_NOT_FOUND':
        'This ride could not be found. It may no longer be available for review.',
    'BOOKING_NOT_COMPLETED':
        'You can only review a ride after it\'s completed. Check back once your trip ends.',
    'REVIEW_ALREADY_EXISTS':
        'You\'ve already submitted a review for this ride. Thank you for your feedback!',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // ALERTS (SOS)
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> alert = {
    'INVALID_TOKEN':
        'Your session has expired. Please log in again to use SOS.',
    'BOOKING_NOT_FOUND':
        'The associated booking could not be found.',
    'ACCESS_FORBIDDEN':
        'You can only trigger alerts for your own bookings.',
    'INVALID_BOOKING_DATE':
        'SOS can only be triggered for today\'s active bookings.',
    'DUPLICATE_ALERT':
        'An SOS alert is already active for this booking. Our team has been notified and is on it.',
    'ALERT_NOT_FOUND':
        'This alert could not be found.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // NODAL (QR BOARDING)
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<String, String> nodal = {
    'VEHICLE_NOT_FOUND':
        'This vehicle number isn\'t recognised. Please check the QR sticker and scan again.',
    'ROUTE_NOT_FOUND':
        'No active trip is running for this vehicle right now. Please wait for your scheduled vehicle.',
    'BOOKING_NOT_FOUND':
        'You don\'t have a scheduled booking on this vehicle today.',
    'NOT_NODAL_SHIFT':
        'This booking doesn\'t require QR boarding. You can board directly.',
    'BOARDING_WINDOW_CLOSED':
        'The boarding window has closed (30 minutes after shift time). Please contact your transport team.',
    'ASSIGNMENT_NOT_FOUND':
        'No pickup hub has been assigned to you yet. Please contact your transport coordinator.',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // HTTP STATUS FALLBACKS
  // ─────────────────────────────────────────────────────────────────────────

  static String fromStatusCode(int? statusCode, {String? context}) {
    switch (statusCode) {
      case 400:
        return context ?? 'The request couldn\'t be processed. Please check your input and try again.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'The requested information could not be found.';
      case 409:
        return 'This action conflicts with existing data. Please refresh and try again.';
      case 422:
        return 'Some of the information provided is invalid. Please check and try again.';
      case 429:
        return 'You\'re making too many requests. Please wait a moment and try again.';
      case 500:
        return 'Something went wrong on our end. Please try again in a moment.';
      case 405:
      case 502:
      case 503:
      case 504:
        return 'Our service is temporarily unavailable. Please try again in a few minutes.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NETWORK / CONNECTIVITY
  // ─────────────────────────────────────────────────────────────────────────

  static const String noInternet =
      'No internet connection. Please check your WiFi or mobile data and try again.';
  static const String timeout =
      'The request is taking too long. Please check your connection and try again.';
  static const String serverDown =
      'Our servers are temporarily unavailable. Please try again in a few minutes.';

  // ─────────────────────────────────────────────────────────────────────────
  // GENERIC FALLBACKS (per feature)
  // ─────────────────────────────────────────────────────────────────────────

  static const String loginFailed =
      'Unable to log in. Please check your credentials and try again.';
  static const String otpFailed =
      'Unable to send OTP. Please check your connection and try again.';
  static const String bookingLoadFailed =
      'Unable to load your bookings. Pull down to refresh.';
  static const String bookingCreateFailed =
      'Unable to create booking. Please try again.';
  static const String bookingCancelFailed =
      'Unable to cancel booking. Please try again.';
  static const String bookingUpdateFailed =
      'Unable to update or rebook this booking. Please try again.';
  static const String shiftLoadFailed =
      'Unable to load available shifts. Pull down to refresh.';
  static const String reviewFailed =
      'Unable to submit your review. Please try again.';
  static const String alertFailed =
      'Unable to send SOS. If you\'re in immediate danger, please call emergency services.';
  static const String chatFailed =
      'Unable to load chat. Please try again.';
  static const String messageSendFailed =
      'Message not sent. Please check your connection and try again.';
  static const String announcementLoadFailed =
      'Unable to load announcements. Pull down to refresh.';
  static const String notificationLoadFailed =
      'Unable to load notifications. Pull down to refresh.';
  static const String nodalScanFailed =
      'QR scan failed. Please try scanning again.';

  // ─────────────────────────────────────────────────────────────────────────
  // RESOLUTION HELPER
  // ─────────────────────────────────────────────────────────────────────────

  /// Main resolver: given a response error, extract error_code and map it
  /// to user-friendly text. Falls back gracefully.
  static String resolve({
    required String feature, // 'auth', 'booking', 'shift', etc.
    int? statusCode,
    String? errorCode,
    String? serverMessage,
    int? remainingAttempts,
    String? statusDetail,
    String? fallback,
  }) {
    // 1. Try mapping by error_code
    if (errorCode != null && errorCode.isNotEmpty) {
      if (feature == 'bookingUpdate' && errorCode == 'INVALID_BOOKING_STATUS') {
        final statusMessage = _bookingUpdateStatusMessage(statusDetail);
        if (statusMessage != null) return statusMessage;
      }
      final mapped = _lookupCode(feature, errorCode);
      if (mapped != null) {
        // INVALID_OTP responses carry `details.remaining_attempts` — surface it.
        if (errorCode == 'INVALID_OTP' && remainingAttempts != null) {
          return '$mapped ($remainingAttempts ${remainingAttempts == 1 ? 'attempt' : 'attempts'} remaining)';
        }
        return mapped;
      }
    }

    // 2. On auth endpoints, a 401 without a known error code means invalid
    //    credentials (per API docs) — not an expired session.
    if (feature == 'auth' && statusCode == 401) {
      return fallback ?? 'Invalid credentials. Please check your details and try again.';
    }

    // 3. Try status code based message
    if (statusCode != null && statusCode >= 400) {
      return fromStatusCode(statusCode, context: fallback);
    }

    // 4. Use provided fallback
    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String? _bookingUpdateStatusMessage(String? statusDetail) {
    if (statusDetail == null || statusDetail.trim().isEmpty) return null;
    final normalized = statusDetail
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s_-]+'), '_');
    final key = normalized == 'NOSHOW' ? 'NO_SHOW' : normalized;
    return bookingUpdateStatus[key];
  }

  static String? _lookupCode(String feature, String code) {
    switch (feature) {
      case 'auth':
        return auth[code];
      case 'booking':
        return booking[code];
      case 'bookingUpdate':
        return bookingUpdate[code] ?? bookingUpdateDefensive[code];
      case 'shift':
        return shift[code];
      case 'weekoff':
        return weekoff[code];
      case 'review':
        return review[code];
      case 'alert':
        return alert[code];
      case 'nodal':
        return nodal[code];
      default:
        // Search all maps
        return auth[code] ?? booking[code] ?? shift[code] ??
            weekoff[code] ?? review[code] ?? alert[code] ?? nodal[code];
    }
  }
}

class ApiConstants {
  static const String baseUrl = 'https://api.mltcorporate.com';
  
  static const String login = '/api/v1/auth/employee/login';
  static const String requestOtp = '/api/v1/auth/employee/request-otp';
  static const String verifyOtp = '/api/v1/auth/employee/verify-otp';
  static const String selectTenant = '/api/v1/auth/employee/select-tenant';
  static const String refreshToken = '/api/v1/auth/refresh-token';
  static const String bookings = '/api/v1/bookings/employee';
  static const String weekoffConfig = '/api/v1/weekoff-configs';
  static const String shifts = '/api/v1/shifts';
  static const String createBooking = '/api/v1/bookings/';
  static const String bookingOperations = '/api/v1/bookings';
  static const String reviewTags = '/api/v1/reviews/tags';
  static const String bookingReview = '/api/v1/employee/bookings';
  
  // Push Notification endpoints
  static const String registerFcmToken = '/api/v1/push-notifications/register-token';
  static const String unregisterFcmToken = '/api/v1/push-notifications/unregister-token';
  static const String sendNotification = '/api/v1/push-notifications/send';
  static const String sendBatchNotification = '/api/v1/push-notifications/send-batch';
  
  // Alert endpoints
  static const String triggerAlert = '/api/v1/alerts/trigger';
  static const String myAlerts = '/api/v1/alerts/my-alerts';
  static const String alerts = '/api/v1/alerts';

  // Announcements
  static const String employeeAnnouncements = '/api/v1/employee/announcements';

  // Chat endpoints
  static const String employeeChat = '/api/v1/employee/chat';
  static const String chatSupportedLanguages = '/api/v1/chat/supported-languages';
}

class ApiConstants {
  static const String baseUrl = 'https://api.mltcorporate.com';
  
  static const String login = '/api/v1/app/auth/employee/login';
  static const String requestOtp = '/api/v1/app/auth/employee/request-otp';
  static const String verifyOtp = '/api/v1/app/auth/employee/verify-otp';
  static const String selectTenant = '/api/v1/app/auth/employee/select-tenant';
  static const String refreshToken = '/api/v1/app/auth/refresh-token';

  // Forgot-password flow (employee)
  static const String forgotPassword = '/api/v1/app/auth/employee/forgot-password';
  static const String forgotPasswordVerify = '/api/v1/app/auth/employee/forgot-password/verify';
  static const String setPassword = '/api/v1/app/auth/employee/password';
  static const String bookings = '/api/v1/app/bookings/employee';
  static const String weekoffConfig = '/api/v1/app/weekoff-configs';
  static const String shifts = '/api/v1/app/shifts';
  static const String createBooking = '/api/v1/app/bookings/';
  static const String bookingOperations = '/api/v1/app/bookings';
  static const String reviewTags = '/api/v1/app/reviews/tags';
  static const String bookingReview = '/api/v1/app/employee/bookings';
  
  // Push Notification endpoints
  static const String registerFcmToken = '/api/v1/app/push-notifications/register-token';
  static const String unregisterFcmToken = '/api/v1/app/push-notifications/logout';
  static const String employeeNotifications = '/api/v1/app/employee/notifications';
  
  // Alert endpoints
  static const String triggerAlert = '/api/v1/app/alerts/trigger';
  static const String myAlerts = '/api/v1/app/alerts/my-alerts';
  static const String alerts = '/api/v1/app/alerts';

  // Announcements
  static const String employeeAnnouncements = '/api/v1/app/employee/announcements';

  // Chat endpoints (Employee ↔ Driver real-time messaging)
  static const String employeeChat = '/api/v1/app/employee/chat';
  static const String chatSupportedLanguages = '/api/v1/app/chat/supported-languages';

  // Nodal (QR onboarding) endpoints
  static const String nodalScan = '/api/v1/app/employee/nodal/scan';
  static const String nodalAssignment = '/api/v1/app/employee/nodal/assignment';
}

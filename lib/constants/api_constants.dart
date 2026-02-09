class ApiConstants {
  static const String baseUrl = 'https://api.gocab.tech';
  
  static const String login = '/api/v1/auth/employee/login';
  static const String requestOtp = '/api/v1/auth/employee/request-otp';
  static const String verifyOtp = '/api/v1/auth/employee/verify-otp';
  static const String selectTenant = '/api/v1/auth/employee/select-tenant';
  static const String bookings = '/api/v1/employee/bookings';
  static const String weekoffConfig = '/api/v1/weekoff-configs';
  static const String shifts = '/api/v1/shifts';
  static const String createBooking = '/api/v1/bookings/';
  static const String bookingOperations = '/api/v1/bookings';
  
  // Push Notification endpoints
  static const String registerFcmToken = '/api/v1/push-notifications/register-token';
  static const String unregisterFcmToken = '/api/v1/push-notifications/unregister-token';
  static const String sendNotification = '/api/v1/push-notifications/send';
  static const String sendBatchNotification = '/api/v1/push-notifications/send-batch';
  
  // Alert endpoints
  static const String triggerAlert = '/api/v1/alerts/trigger';
  static const String myAlerts = '/api/v1/alerts/my-alerts';
  static const String alerts = '/api/v1/alerts';
}

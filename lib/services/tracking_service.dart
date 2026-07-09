import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class TrackingService {
  /// Logs an event to Firebase Analytics and the console
  static void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (kDebugMode) {
      print('=============================================');
      print('📊 ANALYTICS EVENT LOGGED: $eventName');
      if (parameters != null) {
        print('   Parameters: $parameters');
      }
      print('=============================================');
    }
    
    FirebaseAnalytics.instance.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }
}

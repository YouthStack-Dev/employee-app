import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/api_constants.dart';
import '../screens/chat_screen.dart';
import 'api_service.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();
  
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_isInitialized) return;

    // Request permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Setup Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
            _handleNavigation(response.payload, navigatorKey);
        },
      );
      
      // Create Android Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'default', // id matches react native
        'Default', // title
        description: 'Default notification channel',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Foreground Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: jsonEncode(message.data), // JSON so the tap handler can route
          );
        }
      });

      // Background Handler Registration
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle when app is opened from a terminated state. The home screen
      // isn't in place yet (SplashScreen is still resolving auth), so defer
      // the deep-link push until after splash has navigated.
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          Future.delayed(const Duration(milliseconds: 2600), () {
            _routeFromData(message.data);
          });
        }
      });

      // Handle open from background (app alive, home already in place).
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _routeFromData(message.data);
      });

      _isInitialized = true;
      
      // Trigger registration if logged in
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('access_token') != null) {
          registerToken();
      }
      
    } else {
      print('User declined or has not accepted permission');
    }
  }
  
  /// Tap handler for the foreground local notification — the payload is the
  /// JSON-encoded FCM `data` map.
  void _handleNavigation(String? payload, GlobalKey<NavigatorState> navigatorKey) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) _routeFromData(decoded);
    } catch (e) {
      print('Notification payload parse error: $e');
    }
  }

  /// Deep-link from an FCM data payload. Currently handles chat messages:
  ///   data: { type: "chat_message", booking_id: "42", firebase_path: "...", ... }
  /// Navigates to the chat screen for that booking when the user is logged in.
  Future<void> _routeFromData(Map<dynamic, dynamic>? data) async {
    if (data == null) return;
    if (data['type']?.toString() != 'chat_message') return;

    final rawBookingId = data['booking_id'];
    final bookingId = rawBookingId is int ? rawBookingId : int.tryParse(rawBookingId?.toString() ?? '');
    if (bookingId == null) return;

    // Only deep-link when authenticated — otherwise the user is on /login.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => ChatScreen(bookingId: bookingId)),
    );
  }

  Future<void> registerToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
          print('Failed to get FCM token');
          return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final tenantId = prefs.getString('tenant_id');
      
      if (accessToken == null) return;

      // Device Info
      String deviceId = '';
      String deviceModel = '';
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceModel = androidInfo.model;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios-device';
        deviceModel = iosInfo.model;
      }
      
      // App Info
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      
      final payload = {
        "fcm_token": token,
        "device_type": Platform.isAndroid ? 'android' : 'ios',
        "device_id": deviceId,
        "device_model": deviceModel,
        "app_version": packageInfo.version,
        "platform": "app"
      };
      
      print('Registering FCM Token: $payload');

      final response = await _apiService.dio.post(
         ApiConstants.registerFcmToken,
         data: payload,
         options: Options(
           headers: {
             if (tenantId != null) 'X-Tenant-Id': tenantId,
           }
         )
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
          print('FCM Token Registered Successfully');
          
          String? regId;
          if (response.data is Map && response.data['data'] != null && response.data['data']['id'] != null) {
             regId = response.data['data']['id'].toString();
          } else if (response.data is Map && response.data['id'] != null) {
              regId = response.data['id'].toString();
          }
          
          if (regId != null) {
              await prefs.setString('push_registration_id', regId);
          }
      }

    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regId = prefs.getString('push_registration_id');
      
      if (regId == null) return;
      
      print('Unregistering FCM Token ID: $regId');
      
      await _apiService.dio.delete(
        '${ApiConstants.unregisterFcmToken}/$regId'
      );
      
      await prefs.remove('push_registration_id');
      print('Token Unregistered');
      
    } catch (e) {
      print('Error unregistering FCM token: $e');
    }
  }
}

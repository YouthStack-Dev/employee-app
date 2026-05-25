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

// Top-level function required for background FCM handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background FCM message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // ── Android notification channels ─────────────────────────────

  static const _defaultChannel = AndroidNotificationChannel(
    'default',
    'Default',
    description: 'Default notification channel',
    importance: Importance.max,
  );

  static const _chatChannel = AndroidNotificationChannel(
    'chat_channel',
    'Chat Messages',
    description: 'Notifications for new chat messages from your driver',
    importance: Importance.max,
  );

  // ── Initialise ─────────────────────────────────────────────────

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('FCM permission declined');
      return;
    }

    print('FCM permission granted');

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    // Create Android channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Cold-start: app opened from a terminated state by tapping notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        // Delay until navigator is mounted
        Future.delayed(const Duration(milliseconds: 600), () {
          _navigateFromMessage(message.data);
        });
      }
    });

    // Background-to-foreground: app was in background, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromMessage(message.data);
    });

    // Re-register token whenever Firebase rotates it
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('FCM token refreshed — re-registering');
      registerToken();
    });

    _isInitialized = true;

    // Register immediately if already logged in
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') != null) {
      registerToken();
    }
  }

  // ── Foreground message handler ─────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    // Suppress chat banner when the user already has that chat open
    if (type == 'chat_message') {
      final bookingId = int.tryParse(data['booking_id'] ?? '');
      if (bookingId != null && ActiveChat.bookingId == bookingId) {
        return; // user is looking at this conversation — skip banner
      }
    }

    final notification = message.notification;
    final android = notification?.android;
    if (notification == null || android == null) return;

    final channel =
        (type == 'chat_message') ? _chatChannel : _defaultChannel;

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
      payload: _encodePayload(data),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────

  /// Called when a local notification is tapped (foreground-shown banner).
  void _handlePayload(String? payload) {
    if (payload == null) return;
    _navigateFromMessage(Uri.splitQueryString(payload));
  }

  /// Inspects the FCM data map and routes to the right screen.
  void _navigateFromMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final bookingId = int.tryParse((data['booking_id'] ?? '') as String);

    if (type == 'chat_message' && bookingId != null) {
      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(bookingId: bookingId),
        ),
      );
      return;
    }

    // Fallback: go to schedules list
    _navigatorKey?.currentState?.pushNamed('/schedules');
  }

  /// Encodes a data map as a URL query string for use as a local notification payload.
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  // ── Token registration ─────────────────────────────────────────

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

      String deviceId = '';
      String deviceModel = '';
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
        deviceModel = info.model;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'ios-device';
        deviceModel = info.model;
      }

      final packageInfo = await PackageInfo.fromPlatform();

      final payload = {
        'fcm_token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'device_id': deviceId,
        'device_model': deviceModel,
        'app_version': packageInfo.version,
        'platform': 'app',
      };

      print('Registering FCM token: $payload');

      final response = await _apiService.dio.post(
        ApiConstants.registerFcmToken,
        data: payload,
        options: Options(
          headers: {
            if (tenantId != null) 'X-Tenant-Id': tenantId,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('FCM token registered');

        String? regId;
        final respData = response.data;
        if (respData is Map) {
          regId = (respData['data']?['id'] ?? respData['id'])?.toString();
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

      print('Unregistering FCM token ID: $regId');
      await _apiService.dio.delete('${ApiConstants.unregisterFcmToken}/$regId');
      await prefs.remove('push_registration_id');
      print('FCM token unregistered');
    } catch (e) {
      print('Error unregistering FCM token: $e');
    }
  }
}

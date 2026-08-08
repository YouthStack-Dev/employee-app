import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that monitors real internet connectivity.
/// Differentiates between "WiFi connected but no internet" and truly online.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheck;

  bool _isOnline = true;
  bool _hasWifi = false;
  bool _hasMobile = false;
  String _connectionType = 'unknown';

  bool get isOnline => _isOnline;
  bool get hasWifi => _hasWifi;
  bool get hasMobile => _hasMobile;
  String get connectionType => _connectionType;

  /// Human-readable status for UI
  String get statusMessage {
    if (_isOnline) return 'Connected';
    if (_hasWifi) return 'WiFi connected but no internet access';
    if (_hasMobile) return 'Mobile data connected but no internet access';
    return 'No internet connection';
  }

  void _init() {
    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Also do periodic real connectivity checks (every 15s when offline, 30s when online)
    _periodicCheck = Timer.periodic(const Duration(seconds: 15), (_) => checkConnectivity());

    // Initial check
    checkConnectivity();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _hasWifi = results.contains(ConnectivityResult.wifi);
    _hasMobile = results.contains(ConnectivityResult.mobile);

    if (results.contains(ConnectivityResult.none)) {
      _connectionType = 'none';
      _updateOnlineStatus(false);
    } else {
      _connectionType = _hasWifi ? 'wifi' : (_hasMobile ? 'mobile' : 'other');
      // WiFi/mobile connected doesn't mean internet works — verify
      checkConnectivity();
    }
  }

  /// Actually pings a reliable host to confirm internet access.
  /// This catches the "WiFi connected but no internet" case.
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasWifi = results.contains(ConnectivityResult.wifi);
      _hasMobile = results.contains(ConnectivityResult.mobile);

      if (results.contains(ConnectivityResult.none)) {
        _connectionType = 'none';
        _updateOnlineStatus(false);
        return false;
      }

      _connectionType = _hasWifi ? 'wifi' : (_hasMobile ? 'mobile' : 'other');

      // Real internet check — DNS lookup is fast and reliable
      final result = await InternetAddress.lookup('api.mltcorporate.com')
          .timeout(const Duration(seconds: 5));
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateOnlineStatus(hasInternet);
      return hasInternet;
    } on SocketException catch (_) {
      _updateOnlineStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateOnlineStatus(false);
      return false;
    } catch (_) {
      _updateOnlineStatus(false);
      return false;
    }
  }

  void _updateOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _periodicCheck?.cancel();
    super.dispose();
  }
}

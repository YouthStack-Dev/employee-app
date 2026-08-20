import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeFormatProvider extends ChangeNotifier {
  static const _prefsKey = 'time_format_24h';

  bool _is24Hour = true;

  bool get is24Hour => _is24Hour;

  /// Loads the persisted time format preference (defaults to 24-hour).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _is24Hour = prefs.getBool(_prefsKey) ?? true;
    notifyListeners();
  }

  /// Sets the format and persists it.
  /// [is24Hour] = true → "HH:mm" (24-hour), false → "h:mm AM/PM" (12-hour).
  Future<void> setFormat({required bool is24Hour}) async {
    _is24Hour = is24Hour;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, is24Hour);
  }
}
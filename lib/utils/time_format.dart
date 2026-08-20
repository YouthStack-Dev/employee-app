import 'package:intl/intl.dart';

/// Formats a raw time-of-day string ("HH:mm" or "HH:mm:ss") for display.
/// Falls back to a trims the raw string when unparseable.
String formatTimeOfDay(String? raw, {required bool is24Hour}) {
  if (raw == null || raw.trim().isEmpty) return '--:--';
  final parts = raw.trim().split(':');
  if (parts.length < 2) return raw.trim();
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return raw.trim();
  }
  if (is24Hour) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

/// Formats a [DateTime]'s clock portion (no date).
String formatClock(DateTime time, {required bool is24Hour}) {
  final local = time.toLocal();
  return is24Hour
      ? DateFormat('HH:mm').format(local)
      : DateFormat('h:mm a').format(local);
}

/// Formats a [DateTime] with date + clock.
String formatDateWithClock(DateTime time, {required bool is24Hour}) {
  final local = time.toLocal();
  return is24Hour
      ? DateFormat('EEEE, MMMM d, y, HH:mm').format(local)
      : DateFormat('EEEE, MMMM d, y, h:mm a').format(local);
}

/// Formats a date with 'MMM d, h:mm' style clock.
String formatDateShortWithClock(DateTime time, {required bool is24Hour}) {
  final local = time.toLocal();
  return is24Hour
      ? DateFormat('MMM d, HH:mm').format(local)
      : DateFormat('MMM d, h:mm a').format(local);
}
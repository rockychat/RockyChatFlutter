/// Centralised helpers for JSON field extraction.
///
/// Eliminates the `??`-chain hell that was repeated in every model's
/// `fromJson` factory.
library;

class JsonHelpers {
  JsonHelpers._();

  /// Parse an int from any of [keys] (tried in order).  Also handles
  /// String-to-int conversion.
  static int? parseInt(Map<String, dynamic> json, String key1,
      [String? key2, String? key3, String? key4]) {
    for (final key in [key1, key2, key3, key4]) {
      if (key == null) continue;
      final v = json[key];
      if (v == null) continue;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  /// Parse a String from any of [keys] (tried in order).
  static String? parseString(Map<String, dynamic> json, String key1,
      [String? key2, String? key3, String? key4]) {
    for (final key in [key1, key2, key3, key4]) {
      if (key == null) continue;
      final v = json[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Parse a bool from any of [keys] (tried in order).
  static bool? parseBool(Map<String, dynamic> json, String key1,
      [String? key2]) {
    for (final key in [key1, key2]) {
      if (key == null) continue;
      final v = json[key];
      if (v is bool) return v;
    }
    return null;
  }

  /// Parse a date-time string, normalising bare timezone offsets
  /// (e.g. `+08` → `+08:00`) so that [DateTime.parse] succeeds.
  static DateTime? parseDateTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final fixed = s.replaceAllMapped(
      RegExp(r'([+-]\d{2})(?![\d:])'),
      (m) => '${m.group(1)}:00',
    );
    return DateTime.tryParse(fixed);
  }
}

import '../config.dart';

/// Resolve avatar URL - mirrors web/utils/avatar.js
String? getAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

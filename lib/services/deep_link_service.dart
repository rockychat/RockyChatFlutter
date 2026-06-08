import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';

/// Listens for incoming [ideaura://] / [rockychat://] deep links on all
/// platforms and delegates OIDC token extraction to [AuthProvider].
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<String>? _sub;
  AuthProvider? _authProvider;

  /// Attach an [AuthProvider] after construction so we can route tokens.
  void setAuthProvider(AuthProvider auth) {
    _authProvider = auth;
  }

  /// Call once from [main] / the root widget.
  /// Handles both cold-start links (app launched via deep link) and
  /// warm links (app already running when link arrives).
  Future<void> init() async {
    // ── Cold-start link (app was not running) ───────────────────────
    try {
      final initialLink = await _appLinks.getInitialLinkString();
      if (initialLink != null) {
        debugPrint('[DeepLink] Cold-start link: $initialLink');
        _handleRawLink(initialLink);
      }
    } catch (e) {
      debugPrint('[DeepLink] Could not get initial link: $e');
    }

    // ── Warm links (app foregrounded via deep link) ──────────────────
    // Use stringLinkStream instead of uriLinkStream so that the raw URL
    // string is preserved without Dart's Uri normalisation (which
    // lowercases the host portion — fatal for case-sensitive JWT tokens).
    _sub = _appLinks.stringLinkStream.listen(
      (rawLink) {
        debugPrint('[DeepLink] Warm link: $rawLink');
        _handleRawLink(rawLink);
      },
      onError: (err) {
        debugPrint('[DeepLink] Stream error: $err');
      },
    );
  }

  /// Dispose the stream subscription when the service is no longer needed.
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Extract the OIDC token from the raw deep-link string.
  ///
  /// The server redirects to:
  ///   ideaura://token=<jwt>   (Android)
  ///   rockychat://token=<jwt> (iOS)
  ///
  /// We **cannot** use [Uri.parse] here because Dart lowercases the host
  /// component per RFC 3986, which corrupts case-sensitive JWT tokens.
  /// Instead, we parse the raw string directly.
  void _handleRawLink(String rawLink) {
    // Accept both ideaura:// and rockychat:// schemes
    String? afterScheme;
    if (rawLink.startsWith('rockychat://')) {
      afterScheme = rawLink.substring('rockychat://'.length);
    } else if (rawLink.startsWith('ideaura://')) {
      afterScheme = rawLink.substring('ideaura://'.length);
    } else {
      return;
    }
    String? token;

    // Format 1: scheme://token=<jwt>  (server's current format)
    if (afterScheme.startsWith('token=')) {
      token = afterScheme.substring('token='.length);
      // Strip any trailing fragment or query (shouldn't exist, but be safe)
      final hashIdx = token.indexOf('#');
      if (hashIdx != -1) token = token.substring(0, hashIdx);
      debugPrint('[DeepLink] Extracted token from raw URL (direct format)');
    }

    // Format 2: rockychat://?token=<jwt>  or  rockychat://callback?token=<jwt>
    if (token == null || token.isEmpty) {
      final match = RegExp(r'[?&]token=([^&#]+)').firstMatch(rawLink);
      if (match != null) {
        token = match.group(1);
        debugPrint('[DeepLink] Extracted token from query parameter');
      }
    }

    if (token != null && token.isNotEmpty) {
      debugPrint('[DeepLink] OIDC token received (${token.length} chars), logging in…');
      _authProvider?.handleOidcCallback(token);
    } else {
      debugPrint('[DeepLink] rockychat:// received but no token found: $rawLink');
    }
  }
}

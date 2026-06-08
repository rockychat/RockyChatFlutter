import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/user.dart';
import '../services/api_client.dart';

/// Authentication state, mirroring web/contexts/AuthContext.jsx.
class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  static const _storage = FlutterSecureStorage();

  User? _user;
  String? _token;
  bool _loading = true;
  bool _isAuthenticated = false;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get isAuthenticated => _isAuthenticated;
  ApiClient get api => _api;

  AuthProvider(this._api) {
    _loadStoredAuth();
  }

  // ─── Load Stored Auth ──────────────────────────────────────────
  Future<void> _loadStoredAuth() async {
    try {
      final storedToken = await _storage.read(key: 'authToken');
      final storedUser = await _storage.read(key: 'currentUser');

      if (storedToken != null && storedUser != null) {
        _token = storedToken;
        _user = User.fromJson(jsonDecode(storedUser) as Map<String, dynamic>);
        _isAuthenticated = true;
        _api.setToken(_token);
        notifyListeners();

        // Fetch latest user info in background
        _updateCurrentUser();
      }
    } catch (e) {
      debugPrint('Failed to load stored auth: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Login ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final result = await _api.request('/api/auth/login',
          method: 'POST', data: {'email': email, 'password': password});

      if (result.success) {
        final data = result.data as Map<String, dynamic>;
        final newToken = data['token'] as String;
        final userData = data['user'] as Map<String, dynamic>;
        final newUser = User.fromJson(userData);

        _token = newToken;
        _user = newUser;
        _isAuthenticated = true;
        _api.setToken(newToken);

        await _storage.write(key: 'authToken', value: newToken);
        await _storage.write(key: 'currentUser', value: jsonEncode(newUser.toJson()));

        notifyListeners();
        return {'success': true};
      } else {
        return {'success': false, 'message': result.message ?? '登录失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // ─── Register ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      final result = await _api.request('/api/auth/register',
          method: 'POST',
          data: {'username': username, 'email': email, 'password': password});

      if (result.success) {
        return {'success': true, 'message': result.data?['message'] ?? '注册成功！请查收验证邮件'};
      } else {
        return {'success': false, 'message': result.message ?? '注册失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接失败'};
    }
  }

  // ─── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.delete(key: 'authToken');
    await _storage.delete(key: 'currentUser');
    _token = null;
    _user = null;
    _isAuthenticated = false;
    _api.setToken(null);
    notifyListeners();
  }

  // ─── Update User Info ──────────────────────────────────────────
  Future<void> _updateCurrentUser() async {
    final result = await _api.request('/api/users/me');
    if (result.success) {
      final data = result.data as Map<String, dynamic>;
      _user = User(
        id: data['uid'] as int? ?? _user!.id,
        username: data['username'] as String? ?? _user!.username,
        email: data['email'] as String?,
        avatarUrl: data['avatar_url'] as String? ??
            data['avatarUrl'] as String? ??
            data['avatar'] as String?,
        emailVerified: data['emailVerified'] as bool?,
        registrationOrder: data['registrationOrder'] as int?,
        registrationDate: data['registrationDate'] as String?,
        joinDuration: data['joinDuration'] as String?,
      );
      await _storage.write(key: 'currentUser', value: jsonEncode(_user!.toJson()));
      notifyListeners();
    }
  }

  // ─── OIDC Login ────────────────────────────────────────────────
  /// Desktop: uses WebSocket to wait for auth callback.
  /// Mobile: uses URL scheme (app link) for callback.
  Future<Map<String, dynamic>> loginWithOidc() async {
    try {
      final preLoginResult = await _api.request('/api/auth/oidc/pre-login');
      if (!preLoginResult.success) {
        return {'success': false, 'message': '无法初始化 OIDC 登录'};
      }

      final data = preLoginResult.data as Map<String, dynamic>;
      final secureString = data['secureString'] as String;
      final authString = data['authString'] as String;
      final topic = 'oidc/login/$secureString';
      final verifyTopic = 'oidc/verify/$secureString';

      final bool isDesktop = !kIsWeb &&
          (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

      if (isDesktop) {
        return _oidcDesktopFlow(secureString, authString, topic, verifyTopic);
      } else {
        return _oidcMobileFlow(secureString);
      }
    } catch (e) {
      return {'success': false, 'message': '初始化登录失败: $e'};
    }
  }

  /// Desktop OIDC flow: keep WS connection alive and wait for token via MQTT.
  Future<Map<String, dynamic>> _oidcDesktopFlow(
      String secureString, String authString, String topic, String verifyTopic) async {
    try {
      final wsUri = Uri.parse(AppConfig.wsEndpoint);
      final channel = WebSocketChannel.connect(wsUri);

      // Send CONNECT message
      channel.sink.add(jsonEncode({'type': 'connect', 'token': secureString}));

      // Open browser for user to login
      final loginUrl = '${AppConfig.apiBase}/api/auth/oidc/login?s=$secureString';

      // Wait for messages on the WebSocket
      await for (final rawMsg in channel.stream) {
        final packet = jsonDecode(rawMsg as String) as Map<String, dynamic>;

        if (packet['type'] == 'connack' && packet['returnCode'] == 0) {
          // Authenticated; subscribe to topic
          channel.sink.add(jsonEncode({
            'type': 'subscribe',
            'messageId': DateTime.now().millisecondsSinceEpoch,
            'topics': [topic],
          }));
        } else if (packet['type'] == 'suback') {
          // Subscribed; send verify and open browser
          channel.sink.add(jsonEncode({
            'type': 'publish',
            'topic': verifyTopic,
            'payload': authString,
            'qos': 1,
          }));
          launchUrl(Uri.parse(loginUrl), mode: LaunchMode.externalApplication);
        } else if (packet['type'] == 'publish' && packet['topic'] == topic) {
          // Received token!
          final loginData =
              jsonDecode(packet['payload'] as String) as Map<String, dynamic>;
          if (loginData['success'] == true && loginData['token'] != null) {
            await channel.sink.close();

            final newToken = loginData['token'] as String;
            final newUser = User.fromJson(loginData['user'] as Map<String, dynamic>);

            _token = newToken;
            _user = newUser;
            _isAuthenticated = true;
            _api.setToken(newToken);

            await _storage.write(key: 'authToken', value: newToken);
            await _storage.write(key: 'currentUser', value: jsonEncode(newUser.toJson()));

            notifyListeners();
            return {'success': true};
          }
        }
      }

      return {'success': false, 'message': 'OIDC 登录超时'};
    } catch (e) {
      return {'success': false, 'message': 'OIDC 登录失败: $e'};
    }
  }

  /// Mobile OIDC flow: open browser with ?mobile=true so the server redirects
  /// back to rockychat://?token=<jwt> which DeepLinkService will catch.
  Future<Map<String, dynamic>> _oidcMobileFlow(String secureString) async {
    final loginUrl =
        '${AppConfig.apiBase}/api/auth/oidc/login?mobile=true&s=$secureString';
    await launchUrl(Uri.parse(loginUrl), mode: LaunchMode.externalApplication);

    // Return a pending state – DeepLinkService will call handleOidcCallback
    // once the browser redirects back to rockychat://?token=<jwt>.
    return {'success': false, 'pending': true, 'message': '请在浏览器中完成登录，完成后将自动返回应用'};
  }

  /// Handle OIDC callback from deep link.
  /// Only the JWT [token] is needed – user info is fetched via '/api/users/me'.
  Future<void> handleOidcCallback(String token) async {
    debugPrint('[AuthProvider] handleOidcCallback called with token (${token.length} chars)');
    _token = token;
    _isAuthenticated = true;
    _api.setToken(token);

    // Persist the token immediately so the app stays logged in on restart.
    await _storage.write(key: 'authToken', value: token);

    // Notify the UI immediately so it transitions to the main screen.
    // User profile will be fetched in the background.
    notifyListeners();

    // Fetch full user profile from the server.
    try {
      final result = await _api.request('/api/users/me');
      if (result.success && result.data != null) {
        final data = result.data as Map<String, dynamic>;
        _user = User(
          id: data['uid'] as int? ?? 0,
          username: data['username'] as String? ?? '',
          email: data['email'] as String?,
          avatarUrl: data['avatar_url'] as String? ??
              data['avatarUrl'] as String? ??
              data['avatar'] as String?,
          emailVerified: data['emailVerified'] as bool?,
          registrationOrder: data['registrationOrder'] as int?,
          registrationDate: data['registrationDate'] as String?,
          joinDuration: data['joinDuration'] as String?,
        );
        await _storage.write(key: 'currentUser', value: jsonEncode(_user!.toJson()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Failed to fetch user profile after OIDC login: $e');
      // Login is still valid — user info will be fetched on next app start.
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import 'api_client.dart';

const int _kMissedPongLimit = 2;

typedef MqttMessageHandler = void Function(Map<String, dynamic> packet);

class _HandlerEntry {
  final MqttMessageHandler handler;
  final List<String>? topics;
  _HandlerEntry(this.handler, {this.topics});
}

/// WebSocket MQTT connection manager.
class MqttService extends ChangeNotifier {
  final ApiClient _api;
  final String Function() _getToken;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  int _missedPongs = 0;

  bool _isConnected = false;
  bool _isSubscribed = false;
  String _connectionStatus = 'disconnected';
  int _reconnectAttempts = 0;

  /// Fixed exponential back-off.  3 s base, doubles up to 60 s cap.
  static const int _reconnectBaseSeconds = 3;
  static const int _reconnectMaxSeconds = 60;

  final List<_HandlerEntry> _handlerEntries = [];

  bool get isConnected => _isConnected;
  bool get isSubscribed => _isSubscribed;
  bool get isOnline => _isConnected && _isSubscribed;
  String get connectionStatus => _connectionStatus;

  MqttService(this._api, this._getToken);

  // ─── Connection Management ─────────────────────────────────────

  void connect() {
    if (_isConnected) return;
    _connectionStatus = 'connecting';
    notifyListeners();

    try {
      final uri = Uri.parse(AppConfig.wsEndpoint);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final packet = jsonDecode(data as String) as Map<String, dynamic>;
            _handlePacket(packet);
          } catch (e) {
            debugPrint('Error parsing MQTT message: $e');
          }
        },
        onError: (error) {
          debugPrint('MQTT WebSocket error: $error');
          _connectionStatus = 'error';
          _isConnected = false;
          _isSubscribed = false;
          _stopHeartbeat();
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('MQTT WebSocket disconnected');
          _isConnected = false;
          _isSubscribed = false;
          _connectionStatus = 'disconnected';
          _stopHeartbeat();
          notifyListeners();
          _scheduleReconnect();
        },
      );

      _sendMessage({'type': 'connect', 'token': _getToken()});
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
      _connectionStatus = 'error';
      notifyListeners();
    }
  }

  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isSubscribed = false;
    _connectionStatus = 'disconnected';
    _reconnectAttempts = 0;
    notifyListeners();
  }

  /// Exponential back-off: min 3 s, max 60 s, doubles each attempt.
  /// [1 << n] is capped at n=5 to keep the shift operand safe from overflow.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final shift =
        _reconnectAttempts < 0 ? 0 : (_reconnectAttempts > 5 ? 5 : _reconnectAttempts);
    final seconds = (_reconnectBaseSeconds * (1 << shift))
        .clamp(_reconnectBaseSeconds, _reconnectMaxSeconds);
    _reconnectAttempts++;
    debugPrint('MQTT reconnect in ${seconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_isConnected) connect();
    });
  }

  // ─── Packet Handling ───────────────────────────────────────────

  void _handlePacket(Map<String, dynamic> packet) {
    final type = packet['type'] as String?;

    switch (type) {
      case 'connack':
        if (packet['returnCode'] == 0) {
          debugPrint('MQTT connection authenticated');
          _isConnected = true;
          _isSubscribed = false;
          _connectionStatus = 'connected';
          _reconnectAttempts = 0;
          _startHeartbeat();
          notifyListeners();
          // Defer subscription slightly so the suback handler can react.
          // If the connection drops before the delay fires, _subscribeToUserInbox
          // bails out early thanks to the internal _isConnected guard.
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_isConnected) _subscribeToUserInbox();
          });
        } else {
          debugPrint('MQTT auth failed');
          _connectionStatus = 'error';
          notifyListeners();
        }
        break;

      case 'publish':
        _dispatchPublish(packet);
        break;

      case 'suback':
        debugPrint('MQTT subscription acknowledged');
        _isSubscribed = true;
        notifyListeners();
        break;

      case 'pingresp':
        _missedPongs = 0;
        break;

      default:
        // Forward unknown packet types to all handlers.
        _dispatchToAll(packet);
    }
  }

  /// Dispatch a publish packet with basic topic matching.
  void _dispatchPublish(Map<String, dynamic> packet) {
    final packetTopic = packet['topic'] as String? ?? '';
    for (final entry in List<_HandlerEntry>.of(_handlerEntries)) {
      // If the handler registered with one or more topics, check for a match.
      if (entry.topics != null && entry.topics!.isNotEmpty) {
        if (!_topicMatches(packetTopic, entry.topics!)) continue;
      }
      try {
        entry.handler(packet);
      } catch (e) {
        debugPrint('Error in MQTT message handler: $e');
      }
    }
  }

  void _dispatchToAll(Map<String, dynamic> packet) {
    for (final entry in _handlerEntries) {
      try {
        entry.handler(packet);
      } catch (e) {
        debugPrint('Error in MQTT message handler: $e');
      }
    }
  }

  /// Simple MQTT topic matching.
  /// Supports:
  /// - exact match: `user/inbox` == `user/inbox`
  /// - single-level wildcard: `user/+/inbox` matches `user/123/inbox`
  /// - multi-level wildcard: `user/#` matches `user/inbox` and `user/123/foo`
  static bool _topicMatches(String topic, List<String> subscribedTopics) {
    for (final sub in subscribedTopics) {
      if (_matchSingle(sub, topic)) return true;
    }
    return false;
  }

  static bool _matchSingle(String pattern, String topic) {
    if (pattern.endsWith('#')) {
      final prefix = pattern.substring(0, pattern.length - 1);
      // "#" alone matches everything; "foo/#" must start with "foo/"
      if (prefix.isEmpty) return true;
      return topic.startsWith(prefix);
    }
    final patternSegments = pattern.split('/');
    final topicSegments = topic.split('/');
    if (patternSegments.length != topicSegments.length) return false;
    for (int i = 0; i < patternSegments.length; i++) {
      if (patternSegments[i] == '+' || patternSegments[i] == '#') continue;
      if (patternSegments[i] != topicSegments[i]) return false;
    }
    return true;
  }

  // ─── User Inbox Subscription ───────────────────────────────────

  Future<void> _subscribeToUserInbox() async {
    try {
      final result = await _api.request('/api/chat/user-inbox-topic');
      if (result.success) {
        final data = result.data as Map<String, dynamic>;
        final inboxTopic = data['inboxTopic'] as String?;
        if (inboxTopic != null) {
          debugPrint('Subscribing to user inbox topic: $inboxTopic');
          subscribe([inboxTopic]);
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to user inbox: $e');
    }
  }

  // ─── Public API ────────────────────────────────────────────────

  void subscribe(List<String> topics) {
    if (!_isConnected) return;
    _sendMessage({
      'type': 'subscribe',
      'messageId': DateTime.now().millisecondsSinceEpoch,
      'topics': topics,
    });
  }

  void publish(String topic, dynamic message, {int qos = 1}) {
    if (!_isConnected) return;
    _sendMessage({
      'type': 'publish',
      'topic': topic,
      'payload': message is String ? message : jsonEncode(message),
      'qos': qos,
    });
  }

  /// Register a message handler. Returns a dispose function.
  ///
  /// If [topics] is provided, the handler is only called for publish
  /// packets whose topic matches (basic +/# wildcard matching).
  VoidCallback addMessageHandler(MqttMessageHandler handler,
      {List<String>? topics}) {
    final entry = _HandlerEntry(handler, topics: topics);
    _handlerEntries.add(entry);
    return () => _handlerEntries.remove(entry);
  }

  // ─── Internals ─────────────────────────────────────────────────

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _missedPongs = 0;
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _missedPongs++;
      if (_missedPongs >= _kMissedPongLimit) {
        debugPrint('MQTT heartbeat timeout, reconnecting...');
        _channel?.sink.close();
        return;
      }
      _sendMessage({'type': 'pingreq'});
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

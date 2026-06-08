import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/topic.dart';
import '../models/friend.dart';
import '../services/api_client.dart';
import '../services/mqtt_service.dart';
import '../models/user.dart';
import '../utils/json_helpers.dart';

/// Chat state, mirroring web/contexts/ChatContext.jsx.
class ChatProvider extends ChangeNotifier {
  final ApiClient _api;
  final MqttService _mqtt;
  final User? Function() _getUser;

  List<Message> _messages = [];
  List<Topic> _topics = [];
  List<Friend> _friends = [];

  String _activeChatType = 'none'; // 'none' | 'topic' | 'private' | 'public'
  Topic? _currentTopic;
  int? _currentPrivateChat;
  bool _loading = false;
  int _onlineCount = 0;
  String? _topicAnnouncement;
  bool _isMuted = false;
  Map<String, dynamic>? _muteInfo;

  VoidCallback? _mqttDispose;

  // ─── Getters ───────────────────────────────────────────────────
  List<Message> get messages => _messages;
  List<Topic> get topics => _topics;
  List<Friend> get friends => _friends;
  String get activeChatType => _activeChatType;
  Topic? get currentTopic => _currentTopic;
  int? get currentPrivateChat => _currentPrivateChat;
  bool get loading => _loading;
  int get onlineCount => _onlineCount;
  String? get topicAnnouncement => _topicAnnouncement;
  bool get isMuted => _isMuted;
  Map<String, dynamic>? get muteInfo => _muteInfo;

  ChatProvider(this._api, this._mqtt, this._getUser);

  void init() {
    _mqttDispose = _mqtt.addMessageHandler(_handleMQTTMessage);
    loadTopics();
    loadFriends();
  }

  // ─── MQTT Message Handling ─────────────────────────────────────
  void _handleMQTTMessage(Map<String, dynamic> packet) {
    if (packet['type'] != 'publish') return;

    try {
      dynamic payload = packet['payload'];
      Map<String, dynamic> data;

      if (payload is String) {
        data = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map) {
        data = Map<String, dynamic>.from(payload);
      } else {
        debugPrint('MQTT: ignoring non-map/non-string payload: ${payload.runtimeType}');
        return;
      }

      debugPrint('MQTT incoming message: messageType=${data['messageType']}, '
          'topicId=${data['topicId'] ?? data['topic_id']}, '
          'sourceType=${data['sourceType']}, '
          'senderId=${data['senderId'] ?? data['sender_id']}');

      // Determine message type
      String messageType = data['messageType'] as String? ?? 'normal';
      String actualType = messageType;

      if (messageType == 'public') {
        actualType = 'public';
      } else if (messageType == 'normal') {
        if (data['topic_id'] != null || data['topicId'] != null) {
          actualType = 'topic';
        } else if (data['sourceType'] == 'private') {
          actualType = 'private';
        } else {
          actualType = 'public';
        }
      }

      if (actualType == 'public') {
        if (_activeChatType == 'public' ||
            (_currentTopic == null && _currentPrivateChat == null)) {
          _addMessage(Message.fromJson(data));
        }
      } else if (actualType == 'topic') {
        // Update topic latest message
        final msgTopicId = data['topic_id'] ?? data['topicId'];
        if (msgTopicId != null) {
          final senderName = data['senderName'] ?? data['sender_username'] ?? data['username'] ?? '未知用户';
          _topics = _topics.map((t) {
            if (t.id.toString() == msgTopicId.toString()) {
              return t.copyWith(
                latestMessage: LatestMessage(
                  content: '$senderName：${data['content']}',
                  createdAt: data['created_at'] ?? data['createdAt'],
                ),
              );
            }
            return t;
          }).toList();

          if (_currentTopic != null &&
              msgTopicId.toString() == _currentTopic!.id.toString()) {
            _addMessage(Message.fromJson(data));
          }
        }
      } else if (actualType == 'private') {
        final user = _getUser();
        final senderId = data['senderId'] ?? data['sender_id'];
        final receiverId = data['receiverId'] ?? data['receiver_id'];

        if (_currentPrivateChat != null &&
            (senderId.toString() == _currentPrivateChat.toString() ||
                receiverId.toString() == _currentPrivateChat.toString())) {
          _addMessage(Message.fromJson(data));
        }

        // Update friends list latest message
        final otherUserId = senderId.toString() == user?.id.toString()
            ? receiverId
            : senderId;
        final senderName = data['senderName'] ?? data['sender_username'] ?? data['username'] ?? '未知用户';

        final idx = _friends.indexWhere(
            (f) => f.id.toString() == otherUserId.toString());
        if (idx >= 0) {
          _friends[idx] = _friends[idx].copyWith(
            latestMessage: FriendLatestMessage(
              content: '$senderName：${data['content']}',
              createdAt: data['created_at'] ?? data['createdAt'],
            ),
          );
        }
        notifyListeners();
      }

      // Handle online count
      if (data['onlineCount'] != null) {
        final rawCount = data['onlineCount'];
        _onlineCount = rawCount is int ? rawCount : int.tryParse(rawCount.toString()) ?? _onlineCount;
        notifyListeners();
      }

      // Handle friend online/offline status broadcast
      if (data['type'] == 'friend_presence') {
        _handleFriendPresence(data);
      }

      // Handle message events (edit, recall)
      if (data['type'] == 'message_event') {
        final eventType = data['eventType'] as String?;
        if (eventType == 'edit' && data['updatedMessage'] != null) {
          _messages = _messages.map((msg) {
            final eventMessageId = data['messageId'] is int
                ? data['messageId']
                : int.tryParse(data['messageId'].toString());
            if (msg.id == eventMessageId) {
              return Message.fromJson({
                ...data['updatedMessage'] as Map<String, dynamic>,
                'id': msg.id,
              });
            }
            return msg;
          }).toList();
          notifyListeners();
        } else if (eventType == 'recall') {
          _messages = _messages.map((msg) {
            final eventMessageId = data['messageId'] is int
                ? data['messageId']
                : int.tryParse(data['messageId'].toString());
            if (msg.id == eventMessageId) {
              return msg.copyWith(
                isRecalled: true,
                messageType: 'recalled',
                content: '[消息已被撤回]',
                recallTime: data['timestamp'] as String?,
              );
            }
            return msg;
          }).toList();
          notifyListeners();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error handling MQTT message: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Handle friend online/offline presence from MQTT broadcast.
  /// Broadcast format:
  /// {
  ///   "type": "friend_presence",
  ///   "eventType": "friend_online" | "friend_offline",
  ///   "friendId": 456,
  ///   "friendName": "张三",
  ///   "friendAvatar": "...",
  ///   "timestamp": "..."
  /// }
  void _handleFriendPresence(Map<String, dynamic> data) {
    final eventType = data['eventType'] as String?;
    final friendId = data['friendId'];

    if (friendId == null || eventType == null) return;

    final isOnline = eventType == 'friend_online';
    final friendIdStr = friendId.toString();
    bool changed = false;

    _friends = _friends.map((f) {
      if (f.id.toString() == friendIdStr) {
        changed = true;
        return f.copyWith(isOnline: isOnline);
      }
      return f;
    }).toList();

    if (changed) {
      debugPrint('Friend $friendIdStr presence updated: ${isOnline ? "online" : "offline"}');
      notifyListeners();
    }
  }

  void _addMessage(Message message) {
    if (_messages.any((m) => m.id == message.id)) return;
    _messages.add(message);
    _messages.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    notifyListeners();
  }

  // ─── Load Data ─────────────────────────────────────────────────
  Future<void> loadTopics() async {
    final result = await _api.request('/api/chat/topics');
    if (result.success) {
      final list = result.data as List? ?? [];
      _topics = list.map((t) => Topic.fromJson(t as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  Future<void> loadFriends() async {
    final result = await _api.request('/api/friends');
    if (result.success) {
      final list = result.data as List? ?? [];
      _friends =
          list.map((f) => Friend.fromJson(f as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  Future<void> loadMessages({
    int? topicId,
    int? privateUserId,
    int? beforeId,
    int offset = 0,
  }) async {
    final isFirstPage = offset == 0;
    if (isFirstPage) {
      _loading = true;
      _messages = [];
      notifyListeners();
    }

    try {
      final pagination = 'limit=50&offset=$offset';

      ApiResult result;
      if (privateUserId != null) {
        result = await _api.request(
            '/api/chat/private-messages/$privateUserId?$pagination');
      } else if (topicId != null) {
        result = await _api.request(
            '/api/chat/topics/$topicId/messages?$pagination');
      } else {
        result = await _api.request('/api/chat/messages?$pagination');
      }

      if (result.success) {
        List msgs;
        if (topicId != null) {
          final data = result.data as Map<String, dynamic>?;
          msgs = data?['messages'] as List? ?? [];
        } else {
          msgs = result.data as List? ?? [];
        }

        debugPrint('ChatProvider: loadMessages beforeId=$beforeId '
            '→ ${msgs.length} msgs from API');

        final parsed = msgs
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList();
        parsed.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

        if (isFirstPage) {
          _messages = parsed;
        } else {
          final existing = _messages.map((m) => m.id).toSet();
          final newOnes = parsed.where((m) => !existing.contains(m.id)).toList();
          debugPrint('ChatProvider: merged ${newOnes.length} new msgs '
              '(had ${_messages.length} total)');
          if (newOnes.isNotEmpty) {
            _messages = [...newOnes, ..._messages];
          }
        }
        notifyListeners();
      }
    } finally {
      if (isFirstPage) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Load older messages using offset-based pagination.
  /// [offset] = number of messages to skip (should equal current count).
  Future<int> loadMoreMessages({required int offset}) async {
    if (_activeChatType == 'public') {
      await loadMessages(offset: offset);
    } else if (_currentTopic != null) {
      await loadMessages(topicId: _currentTopic!.id, offset: offset);
    } else if (_currentPrivateChat != null) {
      await loadMessages(privateUserId: _currentPrivateChat, offset: offset);
    }
    return _messages.length;
  }

  // ─── Navigation ────────────────────────────────────────────────
  Future<void> switchTopic(Topic topic) async {
    _currentTopic = topic;
    _currentPrivateChat = null;
    _activeChatType = 'topic';
    _topicAnnouncement = null; // Clear immediately
    _isMuted = false;
    _topics = _topics.map((t) => t.id == topic.id ? t.copyWith(unreadCount: 0) : t).toList();
    notifyListeners();
    await loadMessages(topicId: topic.id);
    if (topic.id > 0) {
      await _getTopicAnnouncement(topic.id);
      final muteStatus = await _checkMuteStatus(topic.id);
      _isMuted = muteStatus;
      notifyListeners();
    }
  }

  void switchPrivateChat(int userId) {
    _currentPrivateChat = userId;
    _currentTopic = null;
    _activeChatType = 'private';
    _topicAnnouncement = null; // Clear announcement
    _isMuted = false;
    _friends = _friends
        .map((f) => f.id == userId ? f.copyWith(unreadCount: 0) : f)
        .toList();
    notifyListeners();
    loadMessages(privateUserId: userId);
  }

  Future<void> switchToPublicChat() async {
    _currentTopic = null;
    _currentPrivateChat = null;
    _activeChatType = 'public';
    _topicAnnouncement = null; // Clear announcement
    _isMuted = false;
    notifyListeners();
    await loadMessages();
  }

  void resetSelection() {
    _currentTopic = null;
    _currentPrivateChat = null;
    _activeChatType = 'none';
    _messages = [];
    notifyListeners();
  }

  // ─── Send Message ──────────────────────────────────────────────
  Future<bool> sendMessage(String content,
      {bool isMarkdown = false, String? messageSubtype, List<Map<String, dynamic>>? mentions}) async {
    final subtype = messageSubtype ?? (isMarkdown ? 'markdown' : 'text');

    ApiResult result;
    if (_currentPrivateChat != null) {
      result = await _api.request('/api/chat/private-messages',
          method: 'POST',
          data: {
            'receiverId': _currentPrivateChat,
            'content': content,
            'messageSubtype': subtype,
          });
    } else if (_currentTopic != null) {
      final payload = <String, dynamic>{
        'content': content,
        'topicId': _currentTopic!.id,
        'messageSubtype': subtype,
      };
      if (mentions != null && mentions.isNotEmpty) {
        payload['mentions'] = mentions;
      }
      result = await _api.request('/api/chat/messages',
          method: 'POST', data: payload);
    } else {
      result = await _api.request('/api/chat/messages',
          method: 'POST',
          data: {'content': content, 'messageSubtype': subtype});
    }
    return result.success;
  }

  Future<ApiResult> sendImageMessage(File file,
      {int? topicId, int? privateUserId}) async {
    return sendFileMessage(file,
        fileType: 'image', topicId: topicId, privateUserId: privateUserId);
  }

  /// Sends an image, video, or file message - mirrors web's sendImageMessage(file, topicId, privateUserId, fileType, content)
  Future<ApiResult> sendFileMessage(
    File file, {
    String fileType = 'image',
    String content = '',
    int? topicId,
    int? privateUserId,
  }) async {
    String endpoint = '/api/chat/messages';
    final fields = <String, String>{
      'messageSubtype': fileType,
      'content': content,
    };
    if (privateUserId != null) {
      endpoint = '/api/chat/private-messages';
      fields['receiverId'] = privateUserId.toString();
    } else if (topicId != null) {
      fields['topicId'] = topicId.toString();
    }

    return _api.uploadFile(endpoint, file: file, fields: fields);
  }

  // ─── Topic Management ─────────────────────────────────────────
  Future<ApiResult> createTopic(String name, String description) async {
    final result = await _api.request('/api/chat/topics',
        method: 'POST', data: {'name': name, 'description': description});
    if (result.success) await loadTopics();
    return result;
  }

  Future<List<Map<String, dynamic>>> searchTopics(String query) async {
    final result = await _api.request('/api/chat/topics/search?query=$query&limit=20');
    if (result.success) {
      final list = result.data as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<ApiResult> joinTopic(int topicId) async {
    final result = await _api.request('/api/chat/topics/$topicId/join', method: 'POST');
    if (result.success) await loadTopics();
    return result;
  }

  Future<ApiResult> leaveTopic(int topicId) async {
    final result = await _api.request('/api/chat/topics/$topicId/leave', method: 'POST');
    if (result.success) await loadTopics();
    return result;
  }

  Future<List<TopicMember>> getTopicMembers(int topicId) async {
    final result = await _api.request('/api/chat/topics/$topicId/members?limit=50');
    if (result.success) {
      final data = result.data as Map<String, dynamic>?;
      final members = data?['members'] as List? ?? [];
      return members.map((m) => TopicMember.fromJson(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ApiResult> updateTopic(int topicId, Map<String, dynamic> updates) async {
    final result = await _api.request('/api/chat/topics/$topicId', method: 'PUT', data: updates);
    if (result.success) await loadTopics();
    return result;
  }

  // ─── Message Operations ────────────────────────────────────────
  Future<ApiResult> editMessage(int messageId, String content,
      {bool isPrivate = false, bool isMarkdown = false}) async {
    final subtype = isMarkdown ? 'markdown' : 'text';
    final data = <String, dynamic>{
      'content': content,
      'messageSubtype': subtype,
    };
    if (isPrivate) data['isPrivate'] = 'true';
    if (_currentTopic != null) data['topicId'] = _currentTopic!.id;
    return _api.request('/api/chat/messages/$messageId', method: 'PUT', data: data);
  }

  Future<ApiResult> revokeMessage(int messageId,
      {bool isPrivate = false, int? topicId}) async {
    final params = <String>[];
    if (isPrivate) params.add('isPrivate=true');
    if (topicId != null) params.add('topicId=$topicId');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _api.request('/api/chat/messages/$messageId$qs', method: 'DELETE');
  }

  Future<ApiResult> forwardMessages(
      List<int> messageIds, int? targetTopicId, int? targetReceiverId) async {
    return _api.request('/api/chat/messages/forward',
        method: 'POST',
        data: {
          'messageIds': messageIds,
          'targetTopicId': targetTopicId,
          'targetReceiverId': targetReceiverId,
        });
  }

  Future<ApiResult> sendQuoteMessage(String content, int quotedMessageId,
      {int? topicId, int? receiverId}) async {
    final data = <String, dynamic>{
      'content': content,
      'quotedMessageId': quotedMessageId,
    };
    if (receiverId != null) data['receiverId'] = receiverId;
    if (topicId != null) data['topicId'] = topicId;
    return _api.request('/api/chat/messages/quote', method: 'POST', data: data);
  }

  // ─── User Info ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserPublicInfo(int userId) async {
    final result = await _api.request('/api/users/$userId/public');
    return result.success ? result.data as Map<String, dynamic>? : null;
  }

  Future<ApiResult> getUserProfile(int userId) async {
    var result = await _api.request('/api/users/$userId');
    if (!result.success) {
      result = await _api.request('/api/users/$userId/public');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final result = await _api.request('/api/users/search?username=$query&limit=10');
    if (result.success) {
      return (result.data as List?)?.cast<Map<String, dynamic>>() ?? [];
    }
    return [];
  }

  // ─── Announcements & Mute ──────────────────────────────────────
  Future<void> _getTopicAnnouncement(int topicId) async {
    final result = await _api.request('/api/chat/topics/$topicId/announcement');
    if (result.success) {
      final data = result.data as Map<String, dynamic>?;
      _topicAnnouncement = data?['announcement'] as String?;
    } else {
      _topicAnnouncement = null;
    }
    notifyListeners();
  }

  Future<bool> _checkMuteStatus(int topicId) async {
    final result = await _api.request('/api/chat/topics/$topicId/muted/check');
    if (result.success) {
      final data = result.data as Map<String, dynamic>?;
      return data?['isMuted'] == true || data?['is_muted'] == true;
    }
    return false;
  }

  Future<ApiResult> muteUser(int topicId, int userId, {String reason = ''}) {
    return _api.request('/api/chat/topics/$topicId/muted/$userId',
        method: 'POST', data: {'reason': reason});
  }

  Future<ApiResult> unmuteUser(int topicId, int userId) {
    return _api.request('/api/chat/topics/$topicId/muted/$userId', method: 'DELETE');
  }

  Future<ApiResult> removeTopicMember(int topicId, int userId) {
    return _api.request('/api/chat/topics/$topicId/members/$userId', method: 'DELETE');
  }

  void clearTopicMentions(int topicId) {
    _topics = _topics.map((t) =>
        t.id == topicId ? t.copyWith(hasMentions: false, mentionMessageIds: []) : t)
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttDispose?.call();
    super.dispose();
  }
}

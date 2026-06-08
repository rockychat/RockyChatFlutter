import '../utils/json_helpers.dart';

class Friend {
  final int id;
  final String username;
  final String? avatarUrl;
  final String? status;
  final String? createdAt;
  final bool isBot;
  final bool isOnline;
  final int unreadCount;
  final FriendLatestMessage? latestMessage;

  Friend({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.status,
    this.createdAt,
    this.isBot = false,
    this.isOnline = false,
    this.unreadCount = 0,
    this.latestMessage,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    final friendId = JsonHelpers.parseInt(json, 'friendId', 'id') ?? 0;
    return Friend(
      id: friendId,
      username: JsonHelpers.parseString(
              json, 'friendName', 'username', 'friendUsername') ??
          '',
      avatarUrl: JsonHelpers.parseString(
          json, 'avatar_url', 'avatarUrl', 'avatar'),
      status: JsonHelpers.parseString(json, 'status'),
      createdAt:
          JsonHelpers.parseString(json, 'createdAt', 'created_at'),
      isBot: json['isBot'] == true,
      isOnline: json['isOnline'] == true,
      unreadCount: JsonHelpers.parseInt(json, 'unreadCount') ?? 0,
      latestMessage: json['latestMessage'] != null
          ? FriendLatestMessage.fromJson(
              json['latestMessage'] as Map<String, dynamic>)
          : null,
    );
  }

  Friend copyWith({
    bool? isOnline,
    int? unreadCount,
    FriendLatestMessage? latestMessage,
  }) {
    return Friend(
      id: id,
      username: username,
      avatarUrl: avatarUrl,
      status: status,
      createdAt: createdAt,
      isBot: isBot,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      latestMessage: latestMessage ?? this.latestMessage,
    );
  }
}

class FriendLatestMessage {
  final String content;
  final String? createdAt;

  FriendLatestMessage({required this.content, this.createdAt});

  factory FriendLatestMessage.fromJson(Map<String, dynamic> json) {
    return FriendLatestMessage(
      content: JsonHelpers.parseString(json, 'content') ?? '',
      createdAt:
          JsonHelpers.parseString(json, 'createdAt', 'created_at'),
    );
  }
}

class FriendRequest {
  final int id;
  final int senderId;
  final String? senderUsername;
  final String? senderAvatar;
  final int receiverId;
  final String? receiverUsername;
  final String? receiverAvatar;
  final String status;
  final String? createdAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    this.senderUsername,
    this.senderAvatar,
    required this.receiverId,
    this.receiverUsername,
    this.receiverAvatar,
    this.status = 'pending',
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      senderId:
          JsonHelpers.parseInt(json, 'senderId', 'sender_id') ?? 0,
      senderUsername: JsonHelpers.parseString(
          json, 'senderUsername', 'sender_username'),
      senderAvatar: JsonHelpers.parseString(
          json, 'senderAvatar', 'sender_avatar'),
      receiverId:
          JsonHelpers.parseInt(json, 'receiverId', 'receiver_id') ?? 0,
      receiverUsername: JsonHelpers.parseString(
          json, 'receiverUsername', 'receiver_username'),
      receiverAvatar: JsonHelpers.parseString(
          json, 'receiverAvatar', 'receiver_avatar'),
      status: JsonHelpers.parseString(json, 'status') ?? 'pending',
      createdAt:
          JsonHelpers.parseString(json, 'createdAt', 'created_at'),
    );
  }
}

import '../utils/json_helpers.dart';

class LatestMessage {
  final String content;
  final String? createdAt;

  LatestMessage({required this.content, this.createdAt});

  factory LatestMessage.fromJson(Map<String, dynamic> json) {
    return LatestMessage(
      content: JsonHelpers.parseString(json, 'content') ?? '',
      createdAt:
          JsonHelpers.parseString(json, 'createdAt', 'created_at'),
    );
  }
}

class Topic {
  final int id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final int? createdBy;
  final String? creatorName;
  final bool isPrivate;
  final bool isActive;
  final int messageCount;
  final String? lastActivity;
  final String? createdAt;
  final LatestMessage? latestMessage;
  final int unreadCount;
  final bool hasMentions;
  final List<int> mentionMessageIds;

  Topic({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.createdBy,
    this.creatorName,
    this.isPrivate = false,
    this.isActive = true,
    this.messageCount = 0,
    this.lastActivity,
    this.createdAt,
    this.latestMessage,
    this.unreadCount = 0,
    this.hasMentions = false,
    this.mentionMessageIds = const [],
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      name: JsonHelpers.parseString(json, 'name') ?? '',
      description: JsonHelpers.parseString(json, 'description'),
      avatarUrl: JsonHelpers.parseString(
          json, 'avatar_url', 'avatarUrl'),
      createdBy:
          JsonHelpers.parseInt(json, 'created_by', 'createdBy'),
      creatorName:
          JsonHelpers.parseString(json, 'creatorName'),
      isPrivate: json['is_private'] == true || json['isPrivate'] == true,
      isActive: json['is_active'] == true || json['isActive'] == true,
      messageCount:
          JsonHelpers.parseInt(json, 'message_count', 'messageCount') ?? 0,
      lastActivity: JsonHelpers.parseString(
          json, 'last_activity', 'lastActivity'),
      createdAt:
          JsonHelpers.parseString(json, 'created_at', 'createdAt'),
      latestMessage: json['latestMessage'] != null
          ? LatestMessage.fromJson(
              json['latestMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: JsonHelpers.parseInt(json, 'unreadCount') ?? 0,
      hasMentions: json['hasMentions'] as bool? ?? false,
      mentionMessageIds:
          (json['mentionMessageIds'] as List?)?.cast<int>() ?? [],
    );
  }

  Topic copyWith({
    LatestMessage? latestMessage,
    int? unreadCount,
    bool? hasMentions,
    List<int>? mentionMessageIds,
  }) {
    return Topic(
      id: id,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      createdBy: createdBy,
      creatorName: creatorName,
      isPrivate: isPrivate,
      isActive: isActive,
      messageCount: messageCount,
      lastActivity: lastActivity,
      createdAt: createdAt,
      latestMessage: latestMessage ?? this.latestMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMentions: hasMentions ?? this.hasMentions,
      mentionMessageIds: mentionMessageIds ?? this.mentionMessageIds,
    );
  }
}

class TopicMember {
  final int id;
  final String username;
  final String? avatarUrl;
  final int? registrationOrder;
  final String? joinedAt;
  final String role;
  final bool isMuted;

  TopicMember({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.registrationOrder,
    this.joinedAt,
    this.role = 'member',
    this.isMuted = false,
  });

  factory TopicMember.fromJson(Map<String, dynamic> json) {
    return TopicMember(
      id: json['id'] as int,
      username: JsonHelpers.parseString(json, 'username') ?? '',
      avatarUrl: JsonHelpers.parseString(
          json, 'avatar_url', 'avatarUrl', 'avatar', 'userAvatar'),
      registrationOrder:
          JsonHelpers.parseInt(json, 'registration_order'),
      joinedAt: JsonHelpers.parseString(json, 'joined_at'),
      role: JsonHelpers.parseString(json, 'role') ?? 'member',
      isMuted: json['isMuted'] as bool? ?? false,
    );
  }
}

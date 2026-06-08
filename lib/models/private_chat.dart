class PrivateChat {
  final int id;
  final String username;
  final String? avatar;
  final PrivateChatLatestMessage? latestMessage;
  final int unreadCount;

  PrivateChat({
    required this.id,
    required this.username,
    this.avatar,
    this.latestMessage,
    this.unreadCount = 0,
  });

  factory PrivateChat.fromJson(Map<String, dynamic> json) {
    return PrivateChat(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      avatar: json['avatar'] as String? ??
          json['avatar_url'] as String? ??
          json['avatarUrl'] as String? ??
          json['userAvatar'] as String?,
      latestMessage: json['latestMessage'] != null
          ? PrivateChatLatestMessage.fromJson(
              json['latestMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  PrivateChat copyWith({
    PrivateChatLatestMessage? latestMessage,
    int? unreadCount,
  }) {
    return PrivateChat(
      id: id,
      username: username,
      avatar: avatar,
      latestMessage: latestMessage ?? this.latestMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class PrivateChatLatestMessage {
  final String content;
  final String? createdAt;

  PrivateChatLatestMessage({required this.content, this.createdAt});

  factory PrivateChatLatestMessage.fromJson(Map<String, dynamic> json) {
    return PrivateChatLatestMessage(
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

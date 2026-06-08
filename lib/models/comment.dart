class Comment {
  final int id;
  final String content;
  final int? userId;
  final String? username;
  final String? userAvatar;
  final int? parentId;
  final String? createdAt;

  Comment({
    required this.id,
    required this.content,
    this.userId,
    this.username,
    this.userAvatar,
    this.parentId,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      content: json['content'] as String? ?? '',
      userId: json['userId'] as int? ?? json['user_id'] as int?,
      username: json['username'] as String?,
      userAvatar: json['userAvatar'] as String? ?? json['avatar_url'] as String?,
      parentId: json['parentId'] as int? ?? json['parent_id'] as int?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

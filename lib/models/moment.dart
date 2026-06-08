class Moment {
  final int id;
  final int userId;
  final String? username;
  final String? userAvatar;
  final String content;
  final String? type;
  final String? visibility;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String? createdAt;

  Moment({
    required this.id,
    required this.userId,
    this.username,
    this.userAvatar,
    required this.content,
    this.type,
    this.visibility,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.createdAt,
  });

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int? ?? 0,
      username: json['username'] as String?,
      userAvatar: json['userAvatar'] as String? ?? json['avatar_url'] as String?,
      content: json['content'] as String? ?? '',
      type: json['type'] as String?,
      visibility: json['visibility'] as String?,
      likeCount: json['likeCount'] as int? ?? json['like_count'] as int? ?? 0,
      commentCount:
          json['commentCount'] as int? ?? json['comment_count'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

class Community {
  final int id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final int? creatorId;
  final String? creatorName;
  final int memberCount;
  final bool isMember;
  final String? userRole; // null = not a member, 'member', 'admin', 'owner' etc.
  final String? createdAt;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.creatorId,
    this.creatorName,
    this.memberCount = 0,
    this.isMember = false,
    this.userRole,
    this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      creatorId: json['creator_id'] as int? ?? json['creatorId'] as int?,
      creatorName: json['creatorName'] as String?,
      memberCount:
          json['memberCount'] as int? ?? json['member_count'] as int? ?? 0,
      isMember: json['isMember'] as bool? ?? json['is_member'] as bool? ?? false,
      userRole: json['user_role'] as String? ?? json['userRole'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

class Subsection {
  final int id;
  final int communityId;
  final String name;
  final String? description;

  Subsection({
    required this.id,
    required this.communityId,
    required this.name,
    this.description,
  });

  factory Subsection.fromJson(Map<String, dynamic> json) {
    return Subsection(
      id: json['id'] as int,
      communityId: json['communityId'] as int? ?? json['community_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class Post {
  final int id;
  final String title;
  final String content;
  final int? userId;
  final String? username;
  final String? userAvatar;
  final String? authorName;
  final String? authorAvatar;
  final int? communityId;
  final String? communityName;
  final int? subsectionId;
  final String? subsectionName;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final List<String>? tags;
  final String? createdAt;

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.userId,
    this.username,
    this.userAvatar,
    this.authorName,
    this.authorAvatar,
    this.communityId,
    this.communityName,
    this.subsectionId,
    this.subsectionName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.tags,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<String>? parseTags(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return null;
    }

    return Post(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      userId: json['userId'] as int? ?? json['user_id'] as int?,
      username: json['username'] as String?,
      userAvatar: json['userAvatar'] as String? ?? json['avatar_url'] as String?,
      authorName: json['author_name'] as String? ?? json['authorName'] as String? ?? json['username'] as String?,
      authorAvatar: json['author_avatar'] as String? ?? json['authorAvatar'] as String? ?? json['avatar_url'] as String?,
      communityId:
          json['communityId'] as int? ?? json['community_id'] as int?,
      communityName: json['community_name'] as String? ?? json['communityName'] as String?,
      subsectionId:
          json['subsectionId'] as int? ?? json['subsection_id'] as int?,
      subsectionName: json['subsection_name'] as String? ?? json['subsectionName'] as String?,
      likeCount: json['likeCount'] as int? ?? json['like_count'] as int? ?? 0,
      commentCount:
          json['commentCount'] as int? ?? json['comment_count'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      tags: parseTags(json['tags']),
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

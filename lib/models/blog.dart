class Blog {
  final int id;
  final String title;
  final String content;
  final int? userId;
  final String? username;
  final String? userAvatar;
  final String? authorAvatar;
  final String? summary;
  final List<String> tags;
  final int? categoryId;
  final String? categoryName;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final String? contentType;
  final String? createdAt;
  final String? updatedAt;

  Blog({
    required this.id,
    required this.title,
    required this.content,
    this.userId,
    this.username,
    this.userAvatar,
    this.authorAvatar,
    this.summary,
    this.tags = const [],
    this.categoryId,
    this.categoryName,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.contentType,
    this.createdAt,
    this.updatedAt,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      userId: json['userId'] as int? ?? json['user_id'] as int?,
      username: json['username'] as String? ?? json['author_name'] as String?,
      userAvatar: json['userAvatar'] as String? ?? json['avatar_url'] as String?,
      authorAvatar: json['author_avatar'] as String? ?? json['avatar_url'] as String?,
      summary: json['summary'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      categoryId: json['categoryId'] as int? ?? json['category_id'] as int?,
      categoryName: json['categoryName'] as String? ?? json['category_name'] as String?,
      viewCount: json['viewCount'] as int? ?? json['view_count'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? json['like_count'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? json['comment_count'] as int? ?? 0,
      contentType: json['content_type'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      updatedAt: json['updatedAt'] as String? ?? json['updated_at'] as String?,
    );
  }
}

class BlogCategory {
  final int id;
  final String name;
  final int? userId;
  final String? description;
  final int? postCount;
  final String? createdAt;

  BlogCategory({
    required this.id,
    required this.name,
    this.userId,
    this.description,
    this.postCount,
    this.createdAt,
  });

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    return BlogCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      userId: json['userId'] as int? ?? json['user_id'] as int?,
      description: json['description'] as String?,
      postCount: json['post_count'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Comment model matching the web Comment interface.
class BlogComment {
  final int id;
  final int? userId;
  final String username;
  final String? userAvatar;
  final String? avatarUrl;
  final String content;
  final String? createdAt;

  BlogComment({
    required this.id,
    this.userId,
    required this.username,
    this.userAvatar,
    this.avatarUrl,
    required this.content,
    this.createdAt,
  });

  factory BlogComment.fromJson(Map<String, dynamic> json) {
    return BlogComment(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['user_id'] as int?,
      username: json['username'] as String? ?? '匿名',
      userAvatar: json['userAvatar'] as String? ?? json['avatar'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/blog.dart';
import '../services/api_client.dart';

/// Blog state, mirroring web/contexts/BlogContext.jsx.
class BlogProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Blog> _blogs = [];
  List<Blog> _userBlogs = [];
  Blog? _currentBlog;
  List<BlogCategory> _categories = [];
  List<BlogComment> _comments = [];
  bool _loading = false;
  String? _error;

  List<Blog> get blogs => _blogs;
  List<Blog> get userBlogs => _userBlogs;
  Blog? get currentBlog => _currentBlog;
  List<BlogCategory> get categories => _categories;
  List<BlogComment> get comments => _comments;
  bool get loading => _loading;
  String? get error => _error;

  BlogProvider(this._api);

  Future<void> getBlogs({int page = 1, int limit = 20, String tag = ''}) async {
    _loading = true;
    notifyListeners();
    String query = '?page=$page&limit=$limit';
    if (tag.isNotEmpty) query += '&tag=$tag';
    final result = await _api.request('/api/blog$query');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final posts = data['posts'] as List? ?? [];
      _blogs = posts.map((b) => Blog.fromJson(b as Map<String, dynamic>)).toList();
    } else {
      _error = result.message;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> getUserBlogs(int userId, {int page = 1, int limit = 20}) async {
    _loading = true;
    notifyListeners();
    final result =
        await _api.request('/api/blog/user/$userId?page=$page&limit=$limit');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final posts = data['posts'] as List? ?? [];
      _userBlogs =
          posts.map((b) => Blog.fromJson(b as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> getBlogById(int id) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/blog/$id');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      if (data['post'] != null) {
        _currentBlog = Blog.fromJson(data['post'] as Map<String, dynamic>);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> searchBlogs(String query,
      {int page = 1, int limit = 20}) async {
    _loading = true;
    notifyListeners();
    final result =
        await _api.request('/api/blog/search/$query?page=$page&limit=$limit');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final posts = data['posts'] as List? ?? [];
      _blogs = posts.map((b) => Blog.fromJson(b as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<ApiResult> createBlog(Map<String, dynamic> data) async {
    final result = await _api.request('/api/blog', method: 'POST', data: data);
    if (result.success) getBlogs();
    return result;
  }

  Future<ApiResult> updateBlog(int id, Map<String, dynamic> data) async {
    final result = await _api.request('/api/blog/$id', method: 'PUT', data: data);
    if (result.success && _currentBlog?.id == id) {
      await getBlogById(id);
    }
    return result;
  }

  Future<ApiResult> deleteBlog(int id) async {
    return _api.request('/api/blog/$id', method: 'DELETE');
  }

  // ─── Likes (matching web lib/api.ts) ─────────────────────────────

  Future<ApiResult> likePost(int postId) async {
    return _api.request('/api/likes', method: 'POST', data: {'postId': postId});
  }

  Future<ApiResult> unlikePost(int postId) async {
    return _api.request(
      '/api/likes/$postId?targetType=post',
      method: 'DELETE',
    );
  }

  Future<bool> checkLikeStatus(int postId) async {
    final result = await _api.request(
      '/api/likes/check/$postId?targetType=post',
    );
    if (result.success && result.data != null) {
      final data = result.data as Map<String, dynamic>;
      return data['isLiked'] == true;
    }
    return false;
  }

  // ─── Comments (matching web lib/api.ts) ──────────────────────────

  Future<void> fetchComments(int postId) async {
    final result = await _api.request('/api/comments/post/$postId');
    if (result.success && result.data != null) {
      final list = result.data as List? ?? [];
      _comments = list.map((c) => BlogComment.fromJson(c as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  Future<ApiResult> createComment(int postId, String content) async {
    return _api.request('/api/comments', method: 'POST', data: {
      'postId': postId,
      'content': content,
    });
  }

  // ─── Categories ──────────────────────────────────────────────────

  Future<void> getCategories(int userId) async {
    final result = await _api.request('/api/blog/categories/user/$userId');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final cats = data['categories'] as List? ?? [];
      _categories =
          cats.map((c) => BlogCategory.fromJson(c as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  Future<ApiResult> createCategory(Map<String, dynamic> data) async {
    return _api.request('/api/blog/categories', method: 'POST', data: data);
  }

  void setCurrentBlog(Blog? blog) {
    _currentBlog = blog;
    notifyListeners();
  }
}

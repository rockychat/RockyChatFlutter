import 'package:flutter/foundation.dart';
import '../models/community.dart';
import '../models/comment.dart';
import '../services/api_client.dart';

/// Community/forum state, mirroring web/contexts/CommunityContext.jsx.
class CommunityProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Community> _recommendedCommunities = [];
  List<Community> _myCommunities = [];
  Community? _currentCommunity;
  List<Post> _communityPosts = [];
  Post? _currentPost;
  List<Subsection> _subsections = [];
  bool _loading = false;
  String? _error;

  List<Community> get recommendedCommunities => _recommendedCommunities;
  List<Community> get myCommunities => _myCommunities;
  Community? get currentCommunity => _currentCommunity;
  List<Post> get communityPosts => _communityPosts;
  Post? get currentPost => _currentPost;
  List<Subsection> get subsections => _subsections;
  bool get loading => _loading;
  String? get error => _error;

  CommunityProvider(this._api);

  Future<void> fetchRecommendedCommunities() async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/communities/recommended');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['communities'] as List? ?? [];
      _recommendedCommunities =
          list.map((c) => Community.fromJson(c as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchMyCommunities() async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/communities/my/joined');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['communities'] as List? ?? [];
      _myCommunities =
          list.map((c) => Community.fromJson(c as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchCommunityDetails(int id) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/communities/$id');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      if (data['community'] != null) {
        _currentCommunity =
            Community.fromJson(data['community'] as Map<String, dynamic>);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<ApiResult> joinCommunity(int id) async {
    final result = await _api.request('/api/communities/$id/join', method: 'POST');
    if (result.success) {
      await fetchMyCommunities();
      if (_currentCommunity?.id == id) await fetchCommunityDetails(id);
    }
    return result;
  }

  Future<ApiResult> leaveCommunity(int id) async {
    final result = await _api.request('/api/communities/$id/leave', method: 'DELETE');
    if (result.success) {
      await fetchMyCommunities();
      if (_currentCommunity?.id == id) await fetchCommunityDetails(id);
    }
    return result;
  }

  Future<ApiResult> createCommunity(Map<String, dynamic> data) async {
    final result = await _api.request('/api/communities', method: 'POST', data: data);
    if (result.success) await fetchMyCommunities();
    return result;
  }

  // ─── Subsections ───────────────────────────────────────────────
  Future<void> fetchSubsections(int communityId) async {
    final result = await _api.request('/api/subsections/community/$communityId');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['subsections'] as List? ?? [];
      _subsections =
          list.map((s) => Subsection.fromJson(s as Map<String, dynamic>)).toList();
      notifyListeners();
    }
  }

  // ─── Posts ─────────────────────────────────────────────────────
  Future<void> fetchCommunityPosts(int communityId, {int? subsectionId}) async {
    _loading = true;
    notifyListeners();
    String endpoint = '/api/posts/community/$communityId';
    if (subsectionId != null) {
      endpoint = '/api/posts/subsection/$subsectionId';
    }
    final result = await _api.request(endpoint);
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['posts'] as List? ?? [];
      _communityPosts =
          list.map((p) => Post.fromJson(p as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchPostDetails(int id) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/posts/$id');
    if (result.success) {
      final data = result.data as Map<String, dynamic>? ?? {};
      if (data['post'] != null) {
        _currentPost = Post.fromJson(data['post'] as Map<String, dynamic>);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<ApiResult> createPost(Map<String, dynamic> postData) async {
    return _api.request('/api/posts', method: 'POST', data: postData);
  }

  Future<ApiResult> deletePost(int id) async {
    return _api.request('/api/posts/$id', method: 'DELETE');
  }

  Future<ApiResult> likePost(int id) async {
    return _api.request('/api/likes', method: 'POST', data: {'postId': id});
  }

  Future<ApiResult> unlikePost(int id) async {
    return _api.request('/api/likes/$id?targetType=post', method: 'DELETE');
  }

  Future<ApiResult> checkLikeStatus(int id) async {
    return _api.request('/api/likes/check/$id?targetType=post');
  }

  Future<List<Comment>> fetchComments(int postId) async {
    final result = await _api.request('/api/comments/post/$postId');
    if (result.success) {
      List list;
      if (result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;
        list = data['comments'] as List? ?? [];
      } else if (result.data is List) {
        list = result.data as List;
      } else {
        return [];
      }
      return list.map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ApiResult> createComment(int postId, String content) async {
    return _api.request('/api/comments',
        method: 'POST', data: {'postId': postId, 'content': content});
  }

  void setCurrentCommunity(Community? c) {
    _currentCommunity = c;
    notifyListeners();
  }

  void setCurrentPost(Post? p) {
    _currentPost = p;
    notifyListeners();
  }
}

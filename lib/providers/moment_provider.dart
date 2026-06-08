import 'package:flutter/foundation.dart';
import '../models/moment.dart';
import '../models/comment.dart';
import '../services/api_client.dart';

/// Moment/dynamic state, mirroring web/contexts/MomentContext.jsx.
class MomentProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Moment> _publicMoments = [];
  List<Moment> _followingMoments = [];
  List<Moment> _friendMoments = [];
  bool _loading = false;
  String? _error;

  List<Moment> get publicMoments => _publicMoments;
  List<Moment> get followingMoments => _followingMoments;
  List<Moment> get friendMoments => _friendMoments;
  bool get loading => _loading;
  String? get error => _error;

  MomentProvider(this._api);

  Future<void> getPublicMoments({int page = 1, int limit = 20}) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/moments/public?page=$page&limit=$limit');
    if (result.success) {
      final list = result.data as List? ?? [];
      _publicMoments = list.map((m) => Moment.fromJson(m as Map<String, dynamic>)).toList();
    } else {
      _error = result.message;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> getFollowingMoments({int page = 1, int limit = 20}) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/moments/following?page=$page&limit=$limit');
    if (result.success) {
      final list = result.data as List? ?? [];
      _followingMoments =
          list.map((m) => Moment.fromJson(m as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> getFriendMoments({int page = 1, int limit = 20}) async {
    _loading = true;
    notifyListeners();
    final result = await _api.request('/api/moments/friends?page=$page&limit=$limit');
    if (result.success) {
      final list = result.data as List? ?? [];
      _friendMoments =
          list.map((m) => Moment.fromJson(m as Map<String, dynamic>)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<ApiResult> createMoment(String content,
      {String type = 'public', String visibility = 'public'}) async {
    final result = await _api.request('/api/moments',
        method: 'POST',
        data: {'content': content, 'type': type, 'visibility': visibility});
    if (result.success) {
      getPublicMoments();
    }
    return result;
  }

  Future<ApiResult> likeMoment(int momentId) async {
    return _api.request('/api/likes', method: 'POST', data: {'momentId': momentId});
  }

  Future<ApiResult> unlikeMoment(int momentId) async {
    return _api.request('/api/likes/$momentId', method: 'DELETE');
  }

  Future<Moment?> getMomentDetails(int momentId) async {
    final result = await _api.request('/api/moments/$momentId');
    if (result.success) {
      return Moment.fromJson(result.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<Comment>> getMomentComments(int momentId, {int page = 1}) async {
    final result = await _api.request('/api/comments/moment/$momentId?page=$page');
    if (result.success) {
      final list = result.data as List? ?? [];
      return list.map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ApiResult> createComment(int momentId, String content,
      {int? parentId}) async {
    final data = <String, dynamic>{
      'momentId': momentId,
      'content': content,
    };
    if (parentId != null) data['parentId'] = parentId;
    return _api.request('/api/comments', method: 'POST', data: data);
  }
}

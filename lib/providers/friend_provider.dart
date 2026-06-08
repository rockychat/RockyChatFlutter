import 'package:flutter/foundation.dart';
import '../models/friend.dart';
import '../services/api_client.dart';

/// Friend & follow state, mirroring web/contexts/FriendContext.jsx.
class FriendProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Friend> _friends = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  int _friendCount = 0;
  int _pendingCount = 0;
  bool _loading = false;
  String? _error;

  List<Friend> get friends => _friends;
  List<FriendRequest> get receivedRequests => _receivedRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  int get friendCount => _friendCount;
  int get pendingCount => _pendingCount;
  bool get loading => _loading;
  String? get error => _error;

  FriendProvider(this._api);

  Future<void> refreshAll() async {
    _loading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadFriends(),
        _loadReceivedRequests(),
        _loadSentRequests(),
        _loadCounts(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFriends() async {
    final result = await _api.request('/api/friends');
    if (result.success) {
      final list = result.data as List? ?? [];
      _friends = list.map((f) => Friend.fromJson(f as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _loadReceivedRequests() async {
    final result = await _api.request('/api/friends/requests/received');
    if (result.success) {
      final list = result.data as List? ?? [];
      _receivedRequests =
          list.map((r) => FriendRequest.fromJson(r as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _loadSentRequests() async {
    final result = await _api.request('/api/friends/requests/sent');
    if (result.success) {
      final list = result.data as List? ?? [];
      _sentRequests =
          list.map((r) => FriendRequest.fromJson(r as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _loadCounts() async {
    final fcResult = await _api.request('/api/friends/count');
    final pcResult = await _api.request('/api/friends/requests/pending/count');
    if (fcResult.success) {
      _friendCount = (fcResult.data as Map<String, dynamic>?)?['count'] as int? ?? 0;
    }
    if (pcResult.success) {
      _pendingCount = (pcResult.data as Map<String, dynamic>?)?['count'] as int? ?? 0;
    }
  }

  Future<ApiResult> sendFriendRequest(int userId) async {
    final result = await _api.request('/api/friends/request',
        method: 'POST', data: {'userId': userId});
    if (result.success) await _loadSentRequests();
    notifyListeners();
    return result;
  }

  Future<ApiResult> checkFriendStatus(int userId) async {
    return _api.request('/api/friends/check/$userId');
  }

  Future<ApiResult> acceptFriendRequest(int requestId) async {
    final result = await _api.request('/api/friends/request/$requestId/accept',
        method: 'POST', data: {});
    if (result.success) {
      await Future.wait([_loadFriends(), _loadReceivedRequests(), _loadCounts()]);
      notifyListeners();
    }
    return result;
  }

  Future<ApiResult> rejectFriendRequest(int requestId) async {
    final result = await _api.request('/api/friends/request/$requestId',
        method: 'DELETE', data: {});
    if (result.success) {
      await Future.wait([_loadReceivedRequests(), _loadCounts()]);
      notifyListeners();
    }
    return result;
  }

  Future<ApiResult> cancelSentRequest(int requestId) async {
    final result = await _api.request('/api/friends/request/$requestId',
        method: 'DELETE', data: {});
    if (result.success) {
      await _loadSentRequests();
      notifyListeners();
    }
    return result;
  }

  Future<ApiResult> deleteFriend(int friendId) async {
    final result = await _api.request('/api/friends/$friendId',
        method: 'DELETE', data: {});
    if (result.success) {
      await Future.wait([_loadFriends(), _loadCounts()]);
      notifyListeners();
    }
    return result;
  }

  // ─── Follow System ─────────────────────────────────────────────
  Future<ApiResult> followUser(int userId) async {
    return _api.request('/api/follow',
        method: 'POST', data: {'followingId': userId});
  }

  Future<ApiResult> unfollowUser(int userId) async {
    return _api.request('/api/follow/$userId', method: 'DELETE', data: {});
  }

  Future<ApiResult> checkFollowStatus(int userId) async {
    return _api.request('/api/follow/check/$userId');
  }
}

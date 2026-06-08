import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../config.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../utils/json_helpers.dart';

/// Resolves avatar URL
String? _resolveAvatar(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

/// User profile popover matching web/components/UserProfileModal.jsx
/// Shows user avatar, username, UID, registration info, friend/chat action.
class UserProfileModal extends StatefulWidget {
  final int userId;
  final int currentUserId;
  final Offset? anchorPosition;
  final VoidCallback onClose;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.currentUserId,
    this.anchorPosition,
    required this.onClose,
  });

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool? _isFriend;
  bool _sendingRequest = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  /// Simple in-memory cache for friend status checks (keyed by userId).
  /// Periodically pruned on insert to bound memory usage.
  static final Map<int, _CachedStatus> _friendStatusCache = {};
  static DateTime _lastCachePrune = DateTime.now();

  static void _pruneCache() {
    final now = DateTime.now();
    // Prune at most once every 5 minutes.
    if (now.difference(_lastCachePrune).inMinutes < 5) return;
    _lastCachePrune = now;
    _friendStatusCache.removeWhere((_, v) => v.isExpired);
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final chat = context.read<ChatProvider>();
    final friend = context.read<FriendProvider>();
    try {
      final result = await chat.getUserProfile(widget.userId);
      if (result.success && result.data != null) {
        setState(() => _userData = result.data as Map<String, dynamic>);
      }
      // Check friend status (with cache).
      _pruneCache();
      final cached = _friendStatusCache[widget.userId];
      if (cached != null && !cached.isExpired) {
        _isFriend = cached.value;
      } else {
        final friendResult = await friend.checkFriendStatus(widget.userId);
        if (friendResult.success) {
          final data = friendResult.data as Map<String, dynamic>?;
          final value = data?['areFriends'] == true;
          _friendStatusCache[widget.userId] = _CachedStatus(
            value,
            DateTime.now().add(const Duration(minutes: 2)),
          );
          _isFriend = value;
        } else {
          _isFriend = false;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addFriend() async {
    setState(() => _sendingRequest = true);
    final friend = context.read<FriendProvider>();
    final uid = _userData?['uid'] ?? _userData?['id'] ?? widget.userId;
    final result = await friend.sendFriendRequest(uid as int);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('好友请求已发送')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result.message ?? '发送好友请求失败')),
        );
      }
      setState(() => _sendingRequest = false);
    }
  }

  void _startPrivateChat() {
    final chat = context.read<ChatProvider>();
    final uid =
        _userData?['uid'] as int? ?? _userData?['id'] as int? ?? widget.userId;
    chat.switchPrivateChat(uid);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate position (like web: right of anchor, fallback to center)
    double left = screenSize.width / 2 - 144;
    double top = screenSize.height / 2 - 150;
    if (widget.anchorPosition != null) {
      left = widget.anchorPosition!.dx + 12;
      top = widget.anchorPosition!.dy;
      // Ensure within bounds
      if (left + 288 > screenSize.width) {
        left = widget.anchorPosition!.dx - 288 - 12;
      }
      if (top + 300 > screenSize.height) {
        top = screenSize.height - 320;
      }
      left = left.clamp(10.0, screenSize.width - 298.0);
      top = top.clamp(10.0, screenSize.height - 320.0);
    }

    final isSelf = widget.userId == widget.currentUserId;

    return Stack(
      children: [
        // Invisible backdrop to close
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Popover card
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 288,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdwColors.window,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AdwColors.border.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 120,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AdwColors.accent),
                            ),
                          ),
                        )
                      : _userData != null
                          ? _buildContent(isSelf)
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text('无法加载用户信息',
                                    style: TextStyle(
                                        color: AdwColors.fgDim,
                                        fontSize: 13)),
                              ),
                            ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isSelf) {
    final d = _userData!;
    final username = d['username'] as String? ?? 'Unknown';
    final avatarResolved = _resolveAvatar(
        d['avatar_url'] as String? ??
            d['avatar'] as String? ??
            d['avatarUrl'] as String?);
    final uid = d['uid'] ?? d['id'] ?? '';
    final regDate = d['registrationDate'] as String?;
    final regOrder = d['registrationOrder'] as int?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + Name row
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AdwColors.card,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: AdwColors.border.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarResolved != null
                  ? CachedNetworkImage(
                      imageUrl: avatarResolved,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _fallbackAvatar(username))
                  : _fallbackAvatar(username),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AdwColors.fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Icon(Icons.tag,
                          size: 12,
                          color: AdwColors.fgDim.withValues(alpha: 0.7)),
                      const SizedBox(width: 2),
                      Text('$uid',
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AdwColors.fgDim
                                  .withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Divider
        Divider(
            height: 1,
            color: AdwColors.border.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        // Info rows
        if (regDate != null)
          _infoCard(Icons.calendar_today, '注册时间',
              _formatDate(regDate)),
        if (regOrder != null) ...[
          const SizedBox(height: 8),
          _infoCard(Icons.tag, '注册顺序', '#$regOrder'),
        ],
        // Actions (not for self)
        if (!isSelf) ...[
          const SizedBox(height: 16),
          if (_isFriend == true)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startPrivateChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('发送私聊',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdwColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            )
          else if (_isFriend == false)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendingRequest ? null : _addFriend,
                icon: _sendingRequest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add, size: 16),
                label: Text(
                    _sendingRequest ? '发送中...' : '添加好友',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  disabledBackgroundColor: AdwColors.fgDim,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _fallbackAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AdwColors.fgDim),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdwColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AdwColors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AdwColors.fgDim),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AdwColors.fgDim)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AdwColors.fg)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return dateStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _CachedStatus {
  final bool value;
  final DateTime expiresAt;
  _CachedStatus(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

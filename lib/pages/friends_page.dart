import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../config.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../models/friend.dart';
import '../utils/json_helpers.dart';

/// Resolves avatar URL
String? _resolveAvatar(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

/// Friends page with friend list, received/sent requests.
/// Independent Flutter design with Adwaita-style visuals.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendProvider>(
      builder: (context, fp, _) {
        return Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AdwColors.header,
                border: Border(
                    bottom: BorderSide(
                        color: AdwColors.border.withValues(alpha: 0.3),
                        width: 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, size: 20, color: AdwColors.fg),
                  const SizedBox(width: 8),
                  const Text('好友',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdwColors.fg)),
                  const Spacer(),
                  if (fp.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdwColors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${fp.pendingCount} 待处理',
                          style: const TextStyle(
                              color: AdwColors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => fp.refreshAll(),
                    icon: const Icon(Icons.refresh, size: 18),
                    color: AdwColors.fgDim,
                    tooltip: '刷新',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AdwColors.view.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.search,
                          size: 14, color: AdwColors.fgDim),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            color: AdwColors.fg, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: '搜索好友...',
                          hintStyle: TextStyle(
                              color: AdwColors.fgDim, fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close, size: 14),
                        color: AdwColors.fgDim,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
            // Tabs
            Container(
              color: AdwColors.header,
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: AdwColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AdwColors.fg,
                unselectedLabelColor: AdwColors.fgDim,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                dividerColor: AdwColors.border.withValues(alpha: 0.2),
                tabs: [
                  Tab(text: '好友 (${fp.friendCount})'),
                  Tab(text: '收到 (${fp.receivedRequests.length})'),
                  Tab(text: '发出 (${fp.sentRequests.length})'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: fp.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AdwColors.accent))
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _FriendListView(
                            friends: _filterFriends(fp.friends),
                            fp: fp),
                        _ReceivedRequestsView(
                            requests: fp.receivedRequests, fp: fp),
                        _SentRequestsView(
                            requests: fp.sentRequests, fp: fp),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Friend> _filterFriends(List<Friend> friends) {
    if (_searchQuery.isEmpty) return friends;
    return friends
        .where((f) => f.username.toLowerCase().contains(_searchQuery))
        .toList();
  }
}

// ─── Friend List ─────────────────────────────────────────────────────
class _FriendListView extends StatelessWidget {
  final List<Friend> friends;
  final FriendProvider fp;

  const _FriendListView({required this.friends, required this.fp});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AdwColors.card,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.people_outline,
                  size: 32, color: AdwColors.fgDim.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 12),
            Text('暂无好友',
                style: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.5),
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text('快去搜索并添加好友吧',
                style: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.3),
                    fontSize: 12)),
          ],
        ),
      );
    }

    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(friends.length, (i) {
        final friend = friends[i];
        final avatar = _resolveAvatar(friend.avatarUrl);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: AdwColors.hover,
              onTap: () {
                // Start private chat
                context.read<ChatProvider>().switchPrivateChat(friend.id);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdwColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatar != null
                          ? CachedNetworkImage(
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _avatarFallback(friend.username))
                          : _avatarFallback(friend.username),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(friend.username,
                              style: const TextStyle(
                                  color: AdwColors.fg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          if (friend.status != null)
                            Text(friend.status!,
                                style: const TextStyle(
                                    color: AdwColors.fgDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            context
                                .read<ChatProvider>()
                                .switchPrivateChat(friend.id);
                          },
                          icon: const Icon(Icons.chat_bubble_outline,
                              size: 16),
                          color: AdwColors.accent,
                          tooltip: '发送消息',
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AdwColors.card,
                                  title: const Text('删除好友',
                                      style: TextStyle(color: AdwColors.fg)),
                                  content: Text(
                                      '确定要删除好友 ${friend.username} 吗？',
                                      style: const TextStyle(
                                          color: AdwColors.fgDim)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('确定',
                                          style: TextStyle(
                                              color: AdwColors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                fp.deleteFriend(friend.id);
                              }
                            }
                          },
                          icon: Icon(Icons.more_vert,
                              size: 16,
                              color:
                                  AdwColors.fgDim.withValues(alpha: 0.5)),
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          color: AdwColors.card,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除好友',
                                  style: TextStyle(
                                      fontSize: 13, color: AdwColors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

  static Widget _avatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: AdwColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 16),
      ),
    );
  }
}

// ─── Received Requests ─────────────────────────────────────────────
class _ReceivedRequestsView extends StatelessWidget {
  final List<FriendRequest> requests;
  final FriendProvider fp;

  const _ReceivedRequestsView({required this.requests, required this.fp});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox,
                size: 40, color: AdwColors.fgDim.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无好友请求',
                style: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.5),
                    fontSize: 14)),
          ],
        ),
      );
    }

    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(requests.length, (i) {
        final req = requests[i];
        final avatar = _resolveAvatar(req.senderAvatar);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdwColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AdwColors.border.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdwColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatar != null
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                                child: Text(
                                    (req.senderUsername ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: AdwColors.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ))
                      : Center(
                          child: Text(
                              (req.senderUsername ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AdwColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.senderUsername ?? '未知用户',
                          style: const TextStyle(
                              color: AdwColors.fg,
                              fontWeight: FontWeight.w500)),
                      Text(
                        _formatDate(req.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                AdwColors.fgDim.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => fp.acceptFriendRequest(req.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdwColors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    elevation: 0,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('接受',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => fp.rejectFriendRequest(req.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdwColors.red,
                    side: BorderSide(
                        color: AdwColors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('拒绝',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}
}

// ─── Sent Requests ───────────────────────────────────────────────────
class _SentRequestsView extends StatelessWidget {
  final List<FriendRequest> requests;
  final FriendProvider fp;

  const _SentRequestsView({required this.requests, required this.fp});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.outbox,
                size: 40, color: AdwColors.fgDim.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无已发送的请求',
                style: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.5),
                    fontSize: 14)),
          ],
        ),
      );
    }

    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(requests.length, (i) {
        final req = requests[i];
        final avatar = _resolveAvatar(req.receiverAvatar);
        final isPending = req.status == 'pending';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdwColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AdwColors.border.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdwColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatar != null
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                                child: Text(
                                    (req.receiverUsername ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: AdwColors.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ))
                      : Center(
                          child: Text(
                              (req.receiverUsername ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: AdwColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.receiverUsername ?? '未知用户',
                          style: const TextStyle(
                              color: AdwColors.fg,
                              fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPending
                                  ? AdwColors.yellow
                                  : req.status == 'accepted'
                                      ? AdwColors.green
                                      : AdwColors.red,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPending
                                ? '等待回复'
                                : req.status == 'accepted'
                                    ? '已接受'
                                    : '已拒绝',
                            style: TextStyle(
                                fontSize: 11,
                                color: AdwColors.fgDim
                                    .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPending)
                  OutlinedButton(
                    onPressed: () => fp.cancelSentRequest(req.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdwColors.fgDim,
                      side: BorderSide(
                          color: AdwColors.border
                              .withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('取消',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}
}

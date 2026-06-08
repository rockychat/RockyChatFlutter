import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../config.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/mqtt_service.dart';
import '../utils/json_helpers.dart';
import '../utils/about_dialog.dart';

/// Resolves avatar URL
String? _resolveAvatar(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

/// Chat sidebar listing public chat, topics, and private chats.
/// Matches web/components/Sidebar.jsx design.
class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  final _searchController = TextEditingController();
  bool _isCreatingTopic = false;
  bool _showUserMenu = false;
  final _newTopicNameController = TextEditingController();

  // Search state
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _userSearchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _newTopicNameController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _userSearchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final chat = context.read<ChatProvider>();

    // Search topics and users in parallel
    final topicFuture = chat.searchTopics(query);
    final userFuture = chat.searchUsers(query);

    final results = await Future.wait([topicFuture, userFuture]);
    if (mounted) {
      setState(() {
        _searchResults = results[0];
        _userSearchResults = results[1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Column(
          children: [
            // ─── Header ────────────────────────────────────────
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // User Avatar with online-status dot
                  GestureDetector(
                    onTap: () => setState(() => _showUserMenu = !_showUserMenu),
                    child: _buildUserAvatar(auth, context),
                  ),
                  // Center: "Rocky Chat"
                  Expanded(
                    child: Center(
                      child: Text(
                        'Rocky Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AdwColors.fgDim.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  // Add Topic button
                  IconButton(
                    onPressed: () =>
                        setState(() => _isCreatingTopic = !_isCreatingTopic),
                    icon: const Icon(Icons.add, size: 18),
                    color: AdwColors.fgDim,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      hoverColor: AdwColors.hover,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── User Menu Dropdown ─────────────────────────────
            if (_showUserMenu)
              _UserMenuDropdown(
                username: auth.user?.username ?? 'User',
                email: auth.user?.email ?? '',
                avatarUrl: auth.user?.avatarUrl,
                onClose: () => setState(() => _showUserMenu = false),
                onLogout: () {
                  setState(() => _showUserMenu = false);
                  auth.logout();
                },
                onAbout: () {
                  setState(() => _showUserMenu = false);
                  showAppAboutDialog(context);
                },
              ),

            // ─── Search Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ).copyWith(bottom: 16),
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
                      child: Icon(
                        Icons.search,
                        size: 14,
                        color: AdwColors.fgDim,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: AdwColors.fg,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: '搜索会话...',
                          hintStyle: TextStyle(
                            color: AdwColors.fgDim,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_isSearching)
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close, size: 14),
                        color: AdwColors.fgDim,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),

            // ─── Create Topic Form ──────────────────────────────
            if (_isCreatingTopic)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ).copyWith(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AdwColors.view.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _newTopicNameController,
                    autofocus: true,
                    style: const TextStyle(color: AdwColors.fg, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '频道名称...',
                      hintStyle: TextStyle(
                        color: AdwColors.fgDim,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isNotEmpty) {
                        await chat.createTopic(value.trim(), '');
                        _newTopicNameController.clear();
                        setState(() => _isCreatingTopic = false);
                      }
                    },
                  ),
                ),
              ),

            // ─── Chat list / Search results ─────────────────────
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(chat)
                  : _buildChatList(chat),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserAvatar(AuthProvider auth, BuildContext context) {
    final avatarUrl = _resolveAvatar(auth.user?.avatarUrl);
    final isOnline = context.select<MqttService, bool>((m) => m.isOnline);

    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2EC27E),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  (auth.user?.username ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                (auth.user?.username ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        // Discord-style status dot at bottom-right
        Positioned(
          right: -1,
          bottom: -1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isOnline
                ? Container(
                    key: const ValueKey('online'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF23A55A), // Discord green
                      shape: BoxShape.circle,
                      border: Border.all(color: AdwColors.window, width: 1.5),
                    ),
                  )
                : Container(
                    key: const ValueKey('offline'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF80848E), // Discord grey
                        width: 1.5,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Search Results ───────────────────────────────────────────
  Widget _buildSearchResults(ChatProvider chat) {
    if (_searchResults.isEmpty && _userSearchResults.isEmpty) {
      return Center(
        child: Text(
          '没有找到结果',
          style: TextStyle(
            color: AdwColors.fgDim.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      );
    }

    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                '话题',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AdwColors.fgDim,
                ),
              ),
            ),
            ..._searchResults.map((t) {
              final name = t['name'] as String? ?? '';
              final desc = t['description'] as String? ?? '';
              final id = t['id'] as int? ?? 0;
              return _SidebarChatItem(
                avatarWidget: _buildTopicAvatar(name[0], null),
                title: name,
                subtitle: desc.isNotEmpty ? desc : '话题讨论',
                isSelected: false,
                onTap: () async {
                  // Join + switch
                  await chat.joinTopic(id);
                  final topics = chat.topics;
                  final topic = topics.where((tp) => tp.id == id);
                  if (topic.isNotEmpty) {
                    await chat.switchTopic(topic.first);
                  }
                  _searchController.clear();
                  _onSearchChanged('');
                },
              );
            }),
          ],
          if (_userSearchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                '用户',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AdwColors.fgDim,
                ),
              ),
            ),
            ..._userSearchResults.map((u) {
              final name = u['username'] as String? ?? '';
              final uid = u['id'] as int? ?? 0;
              final avatar = (u['avatar_url'] as String?) ??
                  (u['avatarUrl'] as String?) ??
                  (u['avatar'] as String?);
              final resolved = _resolveAvatar(avatar);
              return _SidebarChatItem(
                avatarWidget: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AdwColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: resolved != null
                      ? CachedNetworkImage(
                          imageUrl: resolved,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
                title: name,
                subtitle: '发送私聊消息',
                isSelected: false,
                onTap: () {
                  chat.switchPrivateChat(uid);
                  _searchController.clear();
                  _onSearchChanged('');
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Normal Chat List ─────────────────────────────────────────
  Widget _buildChatList(ChatProvider chat) {
    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Public Chat
          _SidebarChatItem(
            avatarWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2EC27E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.public,
                size: 20,
                color: Color(0xFF2EC27E),
              ),
            ),
            title: '公共聊天室',
            subtitle: '与所有人聊天',
            isSelected: chat.activeChatType == 'public',
            onTap: () => chat.switchToPublicChat(),
          ),

          // Topics Section
          if (chat.topics.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: Text(
                '话题',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AdwColors.fgDim,
                ),
              ),
            ),
            ...chat.topics.map(
              (topic) => _SidebarChatItem(
                avatarWidget: _buildTopicAvatar(
                  topic.name.isNotEmpty ? topic.name[0] : '#',
                  topic.avatarUrl,
                ),
                title: topic.name,
                subtitle: topic.hasMentions
                    ? '[有人@你] '
                    : (topic.latestMessage?.content ??
                          (topic.description ?? '话题讨论')),
                isSelected:
                    chat.activeChatType == 'topic' &&
                    chat.currentTopic?.id == topic.id,
                unreadCount: topic.unreadCount,
                hasMention: topic.hasMentions,
                latestTime: topic.latestMessage?.createdAt,
                onTap: () => chat.switchTopic(topic),
              ),
            ),
          ],

          // Friends
          if (chat.friends.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              child: Text(
                '好友',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AdwColors.fgDim,
                ),
              ),
            ),
            // Sort friends: online first, then offline
            ..._sortedFriends(chat.friends).map((friend) {
              final resolved = _resolveAvatar(friend.avatarUrl);
              return _SidebarChatItem(
                avatarWidget: _buildFriendAvatar(
                  friend.username,
                  resolved,
                  friend.isOnline,
                ),
                title: friend.username,
                subtitle: friend.latestMessage?.content ?? '发送消息',
                isSelected:
                    chat.activeChatType == 'private' &&
                    chat.currentPrivateChat == friend.id,
                unreadCount: friend.unreadCount,
                latestTime: friend.latestMessage?.createdAt,
                onTap: () => chat.switchPrivateChat(friend.id),
              );
            }),
          ],

          // Empty state
          if (chat.topics.isEmpty && chat.friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '暂无会话',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AdwColors.fgDim.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Sort friends: online first, then offline
  List<dynamic> _sortedFriends(List<dynamic> friends) {
    final sorted = List.of(friends);
    sorted.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return 0;
    });
    return sorted;
  }

  /// Build a friend avatar with an online status indicator dot
  Widget _buildFriendAvatar(
    String username,
    String? resolvedUrl,
    bool isOnline,
  ) {
    final avatar = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AdwColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl != null
          ? CachedNetworkImage(
              imageUrl: resolvedUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        // Discord-style status dot at bottom-right
        Positioned(
          right: -1,
          bottom: -1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isOnline
                ? Container(
                    key: const ValueKey('online'),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF23A55A), // Discord green
                      shape: BoxShape.circle,
                      border: Border.all(color: AdwColors.window, width: 2),
                    ),
                  )
                : Container(
                    key: const ValueKey('offline'),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF80848E), // Discord grey
                        width: 2,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicAvatar(String initial, String? avatarUrl) {
    final resolved = _resolveAvatar(avatarUrl);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AdwColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved != null
          ? CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AdwColors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AdwColors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
    );
  }
}

// ─── Sidebar Chat Item ──────────────────────────────────────────────
class _SidebarChatItem extends StatelessWidget {
  final Widget avatarWidget;
  final String title;
  final String subtitle;
  final bool isSelected;
  final int unreadCount;
  final bool hasMention;
  final String? latestTime;
  final VoidCallback onTap;

  const _SidebarChatItem({
    required this.avatarWidget,
    required this.title,
    required this.subtitle,
    this.isSelected = false,
    this.unreadCount = 0,
    this.hasMention = false,
    this.latestTime,
    required this.onTap,
  });

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final dt = JsonHelpers.parseDateTime(timeStr);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected ? AdwColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 1 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: AdwColors.hover,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                avatarWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: AdwColors.fg.withValues(
                                  alpha: isSelected ? 1.0 : 0.9,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (latestTime != null &&
                              _formatTime(latestTime).isNotEmpty)
                            Text(
                              _formatTime(latestTime),
                              style: TextStyle(
                                fontSize: 10,
                                color: AdwColors.fgDim.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AdwColors.fg.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AdwColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── User Menu Dropdown ─────────────────────────────────────────────
class _UserMenuDropdown extends StatelessWidget {
  final String username;
  final String email;
  final String? avatarUrl;
  final VoidCallback onClose;
  final VoidCallback onLogout;
  final VoidCallback onAbout;

  const _UserMenuDropdown({
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.onClose,
    required this.onLogout,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveAvatar(avatarUrl);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdwColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdwColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdwColors.view.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2EC27E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: resolved != null
                      ? CachedNetworkImage(
                          imageUrl: resolved,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AdwColors.fg,
                        ),
                      ),
                      Text(
                        '@${email.split('@').first}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AdwColors.fg.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                _menuItem(Icons.person, '个人资料设置', onClose),
                Divider(
                  height: 1,
                  color: AdwColors.border.withValues(alpha: 0.2),
                  indent: 8,
                  endIndent: 8,
                ),
                _menuItem(Icons.info_outline, '关于', onAbout),
                Divider(
                  height: 1,
                  color: AdwColors.border.withValues(alpha: 0.2),
                  indent: 8,
                  endIndent: 8,
                ),
                _menuItem(Icons.logout, '退出登录', onLogout, isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        hoverColor: isDestructive
            ? AdwColors.red.withValues(alpha: 0.1)
            : AdwColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isDestructive
                    ? AdwColors.red
                    : AdwColors.fgDim.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDestructive ? AdwColors.red : AdwColors.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

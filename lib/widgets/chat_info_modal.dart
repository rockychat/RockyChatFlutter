import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../utils/json_helpers.dart';
import '../config.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/topic.dart';

/// Resolves avatar URL
String? _getAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

/// Chat info modal for topic/user details.
/// Matches web/components/ChatInfoModal.jsx with admin management.
class ChatInfoModal extends StatefulWidget {
  final String type; // 'topic', 'private'
  final int? id;
  final VoidCallback onClose;

  const ChatInfoModal({
    super.key,
    required this.type,
    this.id,
    required this.onClose,
  });

  @override
  State<ChatInfoModal> createState() => _ChatInfoModalState();
}

class _ChatInfoModalState extends State<ChatInfoModal> {
  bool _loading = true;
  String _activeTab = 'info';
  Map<String, dynamic>? _userInfo;
  List<TopicMember> _members = [];
  String _currentUserRole = 'member';

  // Editing state
  bool _isEditing = false;
  final _editNameCtrl = TextEditingController();
  final _editDescCtrl = TextEditingController();
  bool _isEditingAnnouncement = false;
  final _announcementCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _editDescCtrl.dispose();
    _announcementCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    final chat = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    try {
      if (widget.type == 'topic' && widget.id != null) {
        final members = await chat.getTopicMembers(widget.id!);
        final me = members.where(
          (m) => m.id.toString() == auth.user?.id.toString(),
        );
        final topic = chat.currentTopic;
        if (topic != null) {
          _editNameCtrl.text = topic.name;
          _editDescCtrl.text = topic.description ?? '';
        }
        _announcementCtrl.text = chat.topicAnnouncement ?? '';
        setState(() {
          _members = members;
          _currentUserRole = me.isNotEmpty ? me.first.role : 'member';
        });
      } else if (widget.type == 'private' && widget.id != null) {
        final info = await chat.getUserPublicInfo(widget.id!);
        setState(() => _userInfo = info);
      }
    } catch (e) {
      debugPrint('Failed to load info: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _canManage =>
      _currentUserRole == 'creator' || _currentUserRole == 'admin';
  bool get _isCreator => _currentUserRole == 'creator';

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatProvider>();

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 420,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: AdwColors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdwColors.view.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AdwColors.border.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.type == 'topic' ? Icons.tag : Icons.person,
                          size: 18,
                          color: AdwColors.fg,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.type == 'topic' ? '话题信息' : '用户信息',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AdwColors.fg,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, size: 18),
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
                  // Content
                  Flexible(
                    child: SmoothScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  '加载中...',
                                  style: TextStyle(
                                    color: AdwColors.fgDim,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : widget.type == 'topic'
                          ? _buildTopicInfo(chat)
                          : _buildUserInfo(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Topic Info ──────────────────────────────────────────────────
  Widget _buildTopicInfo(ChatProvider chat) {
    final topic = chat.currentTopic;
    if (topic == null) {
      return const Text('无法加载信息', style: TextStyle(color: AdwColors.red));
    }

    final avatarResolved = _getAvatarUrl(topic.avatarUrl);

    return Column(
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AdwColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarResolved != null
              ? CachedNetworkImage(
                  imageUrl: avatarResolved,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.tag, size: 32, color: AdwColors.blue),
                  ),
                )
              : const Center(
                  child: Icon(Icons.tag, size: 32, color: AdwColors.blue),
                ),
        ),
        const SizedBox(height: 12),

        // Editable name + description
        if (_isEditing) ...[
          TextField(
            controller: _editNameCtrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AdwColors.fg,
            ),
            decoration: InputDecoration(
              hintText: '话题名称',
              hintStyle: const TextStyle(color: AdwColors.fgDim),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: AdwColors.border.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AdwColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editDescCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: AdwColors.fg),
            decoration: InputDecoration(
              hintText: '话题描述',
              hintStyle: const TextStyle(color: AdwColors.fgDim),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AdwColors.border.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdwColors.accent),
              ),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (_editNameCtrl.text.trim().isEmpty) return;
                  await chat.updateTopic(topic.id, {
                    'name': _editNameCtrl.text.trim(),
                    'description': _editDescCtrl.text.trim(),
                  });
                  setState(() => _isEditing = false);
                  _loadInfo();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdwColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdwColors.fgDim,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  topic.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AdwColors.fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_canManage) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit, size: 14),
                  color: AdwColors.fgDim,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            topic.description ?? '暂无描述',
            style: const TextStyle(fontSize: 13, color: AdwColors.fgDim),
          ),
        ],

        const SizedBox(height: 20),

        // Tabs
        Row(
          children: [
            _tabButton('概览', 'info'),
            const SizedBox(width: 4),
            _tabButton('成员 (${_members.length})', 'members'),
          ],
        ),
        Divider(height: 1, color: AdwColors.border.withValues(alpha: 0.2)),
        const SizedBox(height: 16),

        // Tab content
        if (_activeTab == 'info') _buildInfoTab(chat, topic),
        if (_activeTab == 'members') _buildMembersTab(chat),
      ],
    );
  }

  Widget _buildInfoTab(ChatProvider chat, Topic topic) {
    return Column(
      children: [
        // Private/Public toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdwColors.view.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                topic.isPrivate ? Icons.lock : Icons.public,
                size: 16,
                color: AdwColors.fg,
              ),
              const SizedBox(width: 8),
              Text(
                topic.isPrivate ? '私有话题' : '公开话题',
                style: const TextStyle(fontSize: 13, color: AdwColors.fg),
              ),
              const Spacer(),
              if (_isCreator)
                GestureDetector(
                  onTap: () async {
                    // Toggle privacy -- web logic
                    // For simplicity, using updateTopic
                    await chat.updateTopic(topic.id, {
                      'is_private': !topic.isPrivate,
                    });
                    _loadInfo();
                  },
                  child: Text(
                    topic.isPrivate ? '设为公开' : '设为私有',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdwColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Creator + creation time
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdwColors.view.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (topic.creatorName != null)
                _infoRow('创建者', topic.creatorName!),
              if (topic.createdAt != null) ...[
                const SizedBox(height: 4),
                _infoRow('创建时间', _formatDate(topic.createdAt!)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Announcement section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdwColors.view.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '话题公告',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AdwColors.fg,
                    ),
                  ),
                  const Spacer(),
                  if (_canManage && !_isEditingAnnouncement)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _isEditingAnnouncement = true),
                      child: const Text(
                        '编辑',
                        style: TextStyle(fontSize: 12, color: AdwColors.accent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isEditingAnnouncement) ...[
                TextField(
                  controller: _announcementCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12, color: AdwColors.fg),
                  decoration: InputDecoration(
                    hintText: '请输入话题公告内容',
                    hintStyle: const TextStyle(
                      color: AdwColors.fgDim,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AdwColors.border.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AdwColors.accent),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // TODO: call setTopicAnnouncementAPI
                        setState(() => _isEditingAnnouncement = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdwColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        _announcementCtrl.text = chat.topicAnnouncement ?? '';
                        setState(() => _isEditingAnnouncement = false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdwColors.fgDim,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ] else
                Text(
                  chat.topicAnnouncement?.isNotEmpty == true
                      ? chat.topicAnnouncement!
                      : '暂无公告',
                  style: const TextStyle(fontSize: 12, color: AdwColors.fgDim),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Leave button (non-creators)
        if (!_isCreator)
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AdwColors.card,
                    title: const Text(
                      '退出话题',
                      style: TextStyle(color: AdwColors.fg),
                    ),
                    content: const Text(
                      '确定要退出该话题吗？',
                      style: TextStyle(color: AdwColors.fgDim),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          '确定',
                          style: TextStyle(color: AdwColors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await chat.leaveTopic(widget.id!);
                  if (mounted) widget.onClose();
                }
              },
              icon: const Icon(
                Icons.exit_to_app,
                size: 16,
                color: AdwColors.red,
              ),
              label: const Text(
                '退出话题',
                style: TextStyle(color: AdwColors.red, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Members Tab ─────────────────────────────────────────────────
  Widget _buildMembersTab(ChatProvider chat) {
    return Column(
      children: _members.map((m) => _buildMemberItem(chat, m)).toList(),
    );
  }

  Widget _buildMemberItem(ChatProvider chat, TopicMember member) {
    final avatarResolved = _getAvatarUrl(member.avatarUrl);
    final showActions = _canManage && member.role != 'creator';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AdwColors.view,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarResolved != null
                  ? CachedNetworkImage(
                      imageUrl: avatarResolved,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _memberAvatarFallback(member.username),
                    )
                  : _memberAvatarFallback(member.username),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.username,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AdwColors.fg,
                        ),
                      ),
                      if (member.role == 'creator') ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.shield,
                          size: 12,
                          color: Color(0xFFEAB308),
                        ),
                      ],
                      if (member.role == 'admin') ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.shield,
                          size: 12,
                          color: AdwColors.blue,
                        ),
                      ],
                      if (member.isMuted) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.volume_off,
                          size: 12,
                          color: AdwColors.red,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    member.role == 'creator'
                        ? '创建者'
                        : member.role == 'admin'
                        ? '管理员'
                        : member.isMuted
                        ? '成员 (已禁言)'
                        : '成员',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdwColors.fgDim,
                    ),
                  ),
                ],
              ),
            ),
            if (showActions) _buildMemberActions(chat, member),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberActions(ChatProvider chat, TopicMember member) {
    return PopupMenuButton<String>(
      onSelected: (action) => _handleMemberAction(chat, action, member),
      icon: Text(
        '···',
        style: TextStyle(
          fontSize: 12,
          color: AdwColors.fgDim.withValues(alpha: 0.6),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
      color: AdwColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'toggleAdmin',
          child: Text(
            member.role == 'admin' ? '取消管理员' : '设为管理员',
            style: const TextStyle(fontSize: 13, color: AdwColors.fg),
          ),
        ),
        PopupMenuItem(
          value: member.isMuted ? 'unmute' : 'mute',
          child: Text(
            member.isMuted ? '解除禁言' : '禁言',
            style: const TextStyle(fontSize: 13, color: AdwColors.fg),
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Text(
            '移出话题',
            style: TextStyle(fontSize: 13, color: AdwColors.red),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMemberAction(
    ChatProvider chat,
    String action,
    TopicMember member,
  ) async {
    switch (action) {
      case 'toggleAdmin':
        // TODO: implement addTopicAdmin / removeTopicAdmin
        break;
      case 'mute':
        final reason = await _showInputDialog('禁言原因', '请输入禁言原因');
        if (reason != null && reason.isNotEmpty && widget.id != null) {
          final result = await chat.muteUser(
            widget.id!,
            member.id,
            reason: reason,
          );
          if (result.success && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('成功禁言用户')));
            _loadInfo();
          }
        }
        break;
      case 'unmute':
        if (widget.id != null) {
          final result = await chat.unmuteUser(widget.id!, member.id);
          if (result.success && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('成功解除禁言')));
            _loadInfo();
          }
        }
        break;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AdwColors.card,
            title: const Text('移出成员', style: TextStyle(color: AdwColors.fg)),
            content: Text(
              '确定要将 ${member.username} 移出话题吗？',
              style: const TextStyle(color: AdwColors.fgDim),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确定', style: TextStyle(color: AdwColors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && widget.id != null) {
          final result = await chat.removeTopicMember(widget.id!, member.id);
          if (result.success && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('成功移除成员')));
            _loadInfo();
          }
        }
        break;
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdwColors.card,
        title: Text(title, style: const TextStyle(color: AdwColors.fg)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AdwColors.fg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AdwColors.fgDim),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdwColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ─── User Info ───────────────────────────────────────────────────
  Widget _buildUserInfo() {
    final info = _userInfo;
    if (info == null) {
      return const Text('无法加载用户信息', style: TextStyle(color: AdwColors.red));
    }

    final username = info['username'] as String? ?? 'Unknown';
    final avatarResolved = _getAvatarUrl(
      info['avatar_url'] as String? ??
          info['avatarUrl'] as String? ??
          info['avatar'] as String?,
    );
    final regDate = info['registrationDate'] as String?;
    final regOrder = info['registrationOrder'] as int?;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF2EC27E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarResolved != null
              ? CachedNetworkImage(
                  imageUrl: avatarResolved,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2EC27E),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2EC27E),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          username,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AdwColors.fg,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '#${info['uid'] ?? info['id'] ?? ''}',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: AdwColors.fgDim,
          ),
        ),
        const SizedBox(height: 20),
        if (regDate != null) ...[
          _detailCard(Icons.calendar_today, '注册时间', _formatDate(regDate)),
          const SizedBox(height: 8),
        ],
        if (regOrder != null) _detailCard(Icons.tag, '注册顺序', '#$regOrder'),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────
  Widget _tabButton(String label, String tab) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AdwColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isActive ? AdwColors.accent : AdwColors.fgDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AdwColors.fgDim),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AdwColors.fg,
          ),
        ),
      ],
    );
  }

  Widget _detailCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdwColors.view.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdwColors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AdwColors.fgDim),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AdwColors.fgDim),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdwColors.fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberAvatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AdwColors.fg,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return dateStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

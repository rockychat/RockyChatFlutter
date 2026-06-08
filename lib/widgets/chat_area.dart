import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../theme.dart';
import '../config.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/message.dart';
import 'smooth_scroll_view.dart';
import 'chat_info_modal.dart';
import 'user_profile_modal.dart';
import 'message_context_menu.dart';
import '../models/topic.dart';
import '../utils/json_helpers.dart';

/// Resolves avatar URL
String? getAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${AppConfig.apiBase}$url';
}

/// Chat area with message list and input.
class ChatArea extends StatefulWidget {
  final VoidCallback onBack;
  const ChatArea({super.key, required this.onBack});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _inputController = TextEditingController();
  late ScrollController _messageScrollController;
  final _inputFocusNode = FocusNode();
  bool _isAnnouncementCollapsed = true;
  bool _isInfoModalOpen = false;
  String _messageMode = 'text';
  bool _initialJumpDone = false;
  bool _isFirstLoad = true;

  // Scroll / unread tracking
  bool _isAtBottom = true;
  int _unreadCount = 0;
  String? _lastMessageId;

  // Chat transition detection
  String _prevChatType = 'none';
  int? _prevTopicId;
  int? _prevPrivateId;
  bool _prevLoading = false;

  // 分页加载
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  // Attachment & emoji
  bool _showAttachmentMenu = false;
  bool _showEmojiPicker = false;
  bool _isSendingFile = false;

  // User profile modal state
  int? _profileUserId;
  Offset? _profileAnchor;

  // Context menu state
  Message? _contextMenuMessage;
  Offset? _contextMenuPosition;
  bool _contextMenuIsOwner = false;
  bool _contextMenuIsAdmin = false;

  // Quoting state
  Message? _quotingMessage;

  // ─── Mention state ──────────────────────────────────────────────
  List<TopicMember> _topicMembers = [];
  bool _showMentionList = false;
  String _mentionSearch = '';
  List<Map<String, dynamic>> _selectedMentions = [];
  int _mentionCursorPos = 0;
  int? _lastTopicId;
  int _memberRequestId = 0;

  @override
  void initState() {
    super.initState();
    _messageScrollController = ScrollController();
    _messageScrollController.addListener(_onScrollUpdate);
  }

  /// 监听滚动位置，判断是否在底部 & 触发分页加载
  /// reverse: true 时，position 0 = 底部，maxScrollExtent = 顶部（最旧消息）
  void _onScrollUpdate() {
    if (!_messageScrollController.hasClients) return;
    final pos = _messageScrollController.position;

    // reverse 模式：pixels 接近 0 表示在底部
    final atBottom = pos.pixels < 100;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (atBottom) _unreadCount = 0;
      });
    }

    // 分页加载：滚动到顶部（reverse 模式下 pixels 接近 maxScrollExtent）
    if (!_isLoadingMore &&
        _hasMoreMessages &&
        pos.maxScrollExtent > 0 &&
        pos.pixels >= pos.maxScrollExtent - 100) {
      debugPrint('ChatArea: triggering loadMore, pixels=${pos.pixels}, '
          'maxExt=${pos.maxScrollExtent}');
      _loadMoreMessages();
    }
  }

  /// 加载更多历史消息（游标分页）
  Future<void> _loadMoreMessages() async {
    final chat = context.read<ChatProvider>();
    if (chat.loading || _isLoadingMore || !_hasMoreMessages) return;
    if (chat.messages.isEmpty) return;

    if (chat.messages.length < 50) {
      _hasMoreMessages = false;
      return;
    }

    setState(() => _isLoadingMore = true);

    final prevCount = chat.messages.length;
    debugPrint('ChatArea: loadMore offset=$prevCount');
    await chat.loadMoreMessages(offset: prevCount);

    if (mounted) {
      final newCount = chat.messages.length;
      debugPrint('ChatArea: after loadMore: $newCount msgs (was $prevCount)');
      // Only mark as "no more" if we got zero new messages back.
      if (newCount <= prevCount && _hasMoreMessages) {
        _hasMoreMessages = false;
        debugPrint('ChatArea: no more messages');
      }
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _messageScrollController.removeListener(_onScrollUpdate);
    _messageScrollController.dispose();
    super.dispose();
  }

  /// 带动画滚动到底部 - 用于发送新消息后
  /// reverse: true 时，底部 = position 0
  void _scrollToBottomAnimated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(ChatProvider chat) async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    _inputController.clear();

    if (_quotingMessage != null && _quotingMessage!.id != null) {
      await chat.sendQuoteMessage(
        content,
        _quotingMessage!.id!,
        topicId: chat.currentTopic?.id,
        receiverId: chat.currentPrivateChat,
      );
    } else {
      await chat.sendMessage(content,
          messageSubtype: _messageMode,
          mentions: _selectedMentions.isNotEmpty ? _selectedMentions : null);
    }
    _scrollToBottomAnimated();
    setState(() {
      _messageMode = 'text';
      _quotingMessage = null;
      _selectedMentions = [];
    });
  }

  /// Returns true if two messages are within 5 minutes — used for
  /// Discord-style avatar grouping.
  static bool _isWithinTimeWindow(Message a, Message b) {
    const maxDiff = Duration(minutes: 5);
    final ta = JsonHelpers.parseDateTime(a.createdAt) ?? DateTime(1970);
    final tb = JsonHelpers.parseDateTime(b.createdAt) ?? DateTime(1970);
    return ta.difference(tb).abs() < maxDiff;
  }

  /// 检测输入中的 @ 符号，触发成员选择菜单
  void _handleInputChange(String val, ChatProvider chat) {
    if (chat.currentTopic == null) {
      setState(() => _showMentionList = false);
      return;
    }

    final cursorPos = _inputController.selection.baseOffset;
    if (cursorPos < 0) {
      setState(() => _showMentionList = false);
      return;
    }

    final textBeforeCursor = val.substring(0, cursorPos);
    final match = RegExp(r'@(\S*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      setState(() {
        _showMentionList = true;
        _mentionSearch = match.group(1) ?? '';
        _mentionCursorPos = cursorPos - _mentionSearch.length - 1;
      });
    } else {
      setState(() => _showMentionList = false);
    }
  }

  /// 选择 @ 成员
  void _handleSelectMention(TopicMember member) {
    final val = _inputController.text;
    final before = val.substring(0, _mentionCursorPos);
    final after = val.substring(_mentionCursorPos + _mentionSearch.length + 1);
    final mentionText = '@${member.username} ';

    _inputController.text = before + mentionText + after;
    // 光标移到插入文本之后
    _inputController.selection = TextSelection.collapsed(
        offset: _mentionCursorPos + mentionText.length);

    setState(() {
      _showMentionList = false;
      _selectedMentions = [
        ..._selectedMentions
            .where((m) => m['id'] != member.id),
        {'type': 'user', 'id': member.id},
      ];
    });
  }

  Future<void> _pickAndSendFile(ChatProvider chat, String fileType) async {
    setState(() => _showAttachmentMenu = false);
    FileType fpType;
    switch (fileType) {
      case 'image':
        fpType = FileType.image;
        break;
      case 'video':
        fpType = FileType.video;
        break;
      default:
        fpType = FileType.any;
    }
    final result = await FilePicker.platform.pickFiles(type: fpType);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() => _isSendingFile = true);
    try {
      await chat.sendFileMessage(
        File(path),
        fileType: fileType,
        topicId: chat.currentTopic?.id,
        privateUserId: chat.currentPrivateChat,
      );
      _scrollToBottomAnimated();
    } catch (e) {
      debugPrint('File send failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件发送失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  void _cycleMessageMode() {
    setState(() {
      if (_messageMode == 'text') {
        _messageMode = 'markdown';
      } else if (_messageMode == 'markdown') {
        _messageMode = 'html';
      } else {
        _messageMode = 'text';
      }
    });
  }

  Color _getSendButtonColor() {
    switch (_messageMode) {
      case 'markdown':
        return const Color(0xFFEF4444);
      case 'html':
        return const Color(0xFFA855F7);
      default:
        return AdwColors.blue;
    }
  }

  Color _getModeIconColor() {
    switch (_messageMode) {
      case 'markdown':
        return const Color(0xFFEF4444);
      case 'html':
        return const Color(0xFFA855F7);
      default:
        return AdwColors.blue;
    }
  }

  String _getPlaceholderText(ChatProvider chat) {
    if (chat.isMuted) return '禁言中...';
    final title = _chatTitle(chat);
    switch (_messageMode) {
      case 'markdown':
        return 'Markdown 模式 - 发送消息至 $title...';
      case 'html':
        return 'HTML 模式 - 发送消息至 $title...';
      default:
        return '发送消息至 $title...';
    }
  }

  String _chatTitle(ChatProvider chat) {
    if (chat.activeChatType == 'public') return '大厅';
    if (chat.currentTopic != null) return chat.currentTopic!.name;
    if (chat.currentPrivateChat != null) {
      final pc = chat.friends.where((f) => f.id == chat.currentPrivateChat);
      return pc.isNotEmpty ? pc.first.username : '私聊';
    }
    return '';
  }

  String _chatDescription(ChatProvider chat) {
    if (chat.activeChatType == 'public') return '公共聊天室';
    if (chat.currentTopic != null) {
      return chat.currentTopic!.description ?? '';
    }
    if (chat.currentPrivateChat != null) return '私聊';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.read<AuthProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    _onChatBuild(chat, auth);

    // ─── Empty state (no chat selected) ──────────────────────────
    if (chat.activeChatType == 'none') {
      return Container(
        color: AdwColors.window,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AdwColors.card,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    size: 40, color: AdwColors.fgDim),
              ),
              const SizedBox(height: 16),
              const Text('欢迎来到花枫咖啡馆',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AdwColors.fg)),
              const SizedBox(height: 8),
              SizedBox(
                width: 240,
                child: Text(
                  '请在左侧选择一个话题或私聊对象开始聊天',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AdwColors.fgDim),
                ),
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: widget.onBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdwColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    elevation: 4,
                  ),
                  child: const Text('选择聊天',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: AdwColors.window,
      child: Stack(
        children: [
          Column(
            children: [
              // ─── Header ──────────────────────────────────────────
              _buildHeader(chat, isDesktop),

              // ─── Announcement Banner ─────────────────────────────
              if (chat.topicAnnouncement != null &&
                  chat.topicAnnouncement!.isNotEmpty)
                _buildAnnouncementBanner(chat),

              // ─── Messages List ───────────────────────────────────
              Expanded(child: _buildMessageList(chat, auth)),
            ],
          ),

          // ─── Mute indicator ────────────────────────────────────
          if (chat.isMuted) _buildMuteIndicator(),

          // ─── Floating Input Footer ─────────────────────────────
          if (!chat.isMuted) _buildInputFooter(chat),

          // ─── New Messages Indicator ────────────────────────────
          if (_unreadCount > 0) _buildNewMessageIndicator(),

          // ─── Info Modal ────────────────────────────────────────
          if (_isInfoModalOpen)
            ChatInfoModal(
              type: chat.activeChatType,
              id: chat.activeChatType == 'topic'
                  ? chat.currentTopic?.id
                  : chat.currentPrivateChat,
              onClose: () => setState(() => _isInfoModalOpen = false),
            ),

          // ─── User Profile Modal ────────────────────────────────
          if (_profileUserId != null)
            UserProfileModal(
              userId: _profileUserId!,
              currentUserId: auth.user?.id ?? 0,
              anchorPosition: _profileAnchor,
              onClose: () => setState(() {
                _profileUserId = null;
                _profileAnchor = null;
              }),
            ),

          // ─── Message Context Menu ──────────────────────────────
          if (_contextMenuMessage != null && _contextMenuPosition != null)
            MessageContextMenu(
              position: _contextMenuPosition!,
              message: _contextMenuMessage!,
              isMessageOwner: _contextMenuIsOwner,
              isTopicAdmin: _contextMenuIsAdmin,
              onClose: () => setState(() {
                _contextMenuMessage = null;
                _contextMenuPosition = null;
              }),
              onCopy: (content) {
                Clipboard.setData(ClipboardData(text: content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板'),
                        duration: Duration(seconds: 1)),
                  );
                }
              },
              onEdit: (msg) {
                _inputController.text = msg.content;
                _inputFocusNode.requestFocus();
              },
              onRevoke: (msg) async {
                if (msg.id != null) {
                  await chat.revokeMessage(
                    msg.id!,
                    isPrivate: chat.activeChatType == 'private',
                    topicId: chat.currentTopic?.id,
                  );
                }
              },
              onForward: (msgs) {
                // TODO: implement forward dialog
              },
              onQuote: (msg) {
                setState(() => _quotingMessage = msg);
                _inputFocusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────
  Widget _buildHeader(ChatProvider chat, bool isDesktop) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdwColors.border.withValues(alpha: 0.2)),
        ),
      ),
      child: Stack(
        children: [
          // Left side
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktop)
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    color: AdwColors.fgDim,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                if (isDesktop) _buildHeaderAvatar(chat),
              ],
            ),
          ),
          // Center: title + description
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_chatTitle(chat),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AdwColors.fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (_chatDescription(chat).isNotEmpty)
                    Text(
                      chat.currentPrivateChat != null
                          ? '私聊'
                          : _chatDescription(chat),
                      style: TextStyle(
                          fontSize: 10,
                          color: AdwColors.fgDim.withValues(alpha: 0.4)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // Right side: action buttons
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none, size: 18),
                  color: AdwColors.fgDim,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _isInfoModalOpen = true),
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: AdwColors.fgDim,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAvatar(ChatProvider chat) {
    final isPrivate = chat.currentPrivateChat != null;
    final title = _chatTitle(chat);
    final avatarUrlStr = isPrivate
        ? chat.friends
            .where((f) => f.id == chat.currentPrivateChat)
            .map((f) => f.avatarUrl)
            .firstOrNull
        : chat.currentTopic?.avatarUrl;
    final resolved = getAvatarUrl(avatarUrlStr);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isPrivate ? const Color(0xFF2EC27E) : const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(isPrivate ? 16 : 8),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved != null
          ? CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                    child: Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ))
          : Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
    );
  }

  // ─── Announcement Banner ─────────────────────────────────────────
  Widget _buildAnnouncementBanner(ChatProvider chat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () => setState(
            () => _isAnnouncementCollapsed = !_isAnnouncementCollapsed),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AdwColors.blue.withValues(alpha: 0.1),
            border: Border.all(color: AdwColors.blue.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AdwColors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('公告',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAnnouncementCollapsed
                          ? chat.topicAnnouncement!
                          : '话题公告',
                      style:
                          const TextStyle(fontSize: 12, color: AdwColors.fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isAnnouncementCollapsed
                        ? Icons.expand_more
                        : Icons.expand_less,
                    size: 14,
                    color: AdwColors.blue,
                  ),
                ],
              ),
              if (!_isAnnouncementCollapsed) ...[
                const SizedBox(height: 8),
                Text(chat.topicAnnouncement!,
                    style:
                        const TextStyle(fontSize: 12, color: AdwColors.fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Detect chat transitions and new messages — called from [build].
  ///
  /// Compares current provider state against previous values so that the
  /// same change is not re-applied across consecutive rebuilds.
  void _onChatBuild(ChatProvider chat, AuthProvider auth) {
    final currentChatType = chat.activeChatType;
    final currentTopicId = chat.currentTopic?.id;
    final currentPrivateId = chat.currentPrivateChat;

    // ── Chat switch detection ──
    final switched = currentChatType != _prevChatType ||
        currentTopicId != _prevTopicId ||
        currentPrivateId != _prevPrivateId;

    if (switched) {
      _prevChatType = currentChatType;
      _prevTopicId = currentTopicId;
      _prevPrivateId = currentPrivateId;
      _initialJumpDone = false;
      _lastMessageId = null;
      _unreadCount = 0;
      _isAtBottom = true;
      _hasMoreMessages = true;
      _selectedMentions = [];
      _showMentionList = false;
    }

    // ── Reset when going back to "none" ──
    if (currentChatType == 'none') {
      _initialJumpDone = false;
      _lastMessageId = null;
      _unreadCount = 0;
      _isAtBottom = true;
      _hasMoreMessages = true;
    }

    // ── Topic members fetch (race-condition safe) ──
    if (currentTopicId != _lastTopicId) {
      _lastTopicId = currentTopicId;
      if (currentTopicId != null) {
        final reqId = ++_memberRequestId;
        chat.getTopicMembers(currentTopicId).then((members) {
          if (mounted && reqId == _memberRequestId) {
            setState(() => _topicMembers = members);
          }
        });
      } else {
        _topicMembers = [];
      }
    }

    if (chat.messages.isEmpty) return;

    // ── Initial load completion ──
    if (!_initialJumpDone && !chat.loading) {
      _initialJumpDone = true;
      _lastMessageId = chat.messages.last.id?.toString();
      return;
    }

    // ── New message detection ──
    final lastMsg = chat.messages.last;
    final lastMsgId = lastMsg.id?.toString();
    if (_initialJumpDone &&
        lastMsgId != null &&
        lastMsgId != _lastMessageId &&
        _lastMessageId != null) {
      final isOwn = lastMsg.senderId == auth.user?.id;
      _lastMessageId = lastMsgId;
      if (_isAtBottom || isOwn) {
        _scrollToBottomAnimated();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _unreadCount++);
        });
      }
    }
  }

  // ─── Message List ────────────────────────────────────────────────
  Widget _buildMessageList(ChatProvider chat, AuthProvider auth) {
    if (chat.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AdwColors.blue.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            const Text('同步历史...',
                style: TextStyle(
                    fontSize: 12,
                    color: AdwColors.fgDim,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (chat.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AdwColors.card,
                  borderRadius: BorderRadius.circular(40)),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 40, color: AdwColors.fgDim),
            ),
            const SizedBox(height: 16),
            const Text('一切准备就绪',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AdwColors.fg)),
            const SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: Text('快来发送第一条消息吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AdwColors.fgDim)),
            ),
          ],
        ),
      );
    }

    // 构建消息 widgets 列表
    final List<Widget> messageWidgets = [];
    for (int i = 0; i < chat.messages.length; i++) {
      final msg = chat.messages[i];
      final isMe = msg.senderId == auth.user?.id;
      final prevMsg = i > 0 ? chat.messages[i - 1] : null;
      final isSameUser = prevMsg != null &&
          prevMsg.senderId == msg.senderId &&
          _isWithinTimeWindow(prevMsg, msg);

      messageWidgets.add(_DiscordStyleMessage(
        message: msg,
        isMe: isMe,
        isSameUser: isSameUser,
        onAvatarTap: (details) {
          if (msg.senderId != null) {
            setState(() {
              _profileUserId = msg.senderId;
              _profileAnchor = details.globalPosition;
            });
          }
        },
        onNameTap: (details) {
          if (msg.senderId != null) {
            setState(() {
              _profileUserId = msg.senderId;
              _profileAnchor = details.globalPosition;
            });
          }
        },
        onContextMenu: (details) {
          setState(() {
            _contextMenuMessage = msg;
            _contextMenuPosition = details.globalPosition;
            _contextMenuIsOwner = isMe;
            _contextMenuIsAdmin = false;
          });
          if (chat.currentTopic != null && chat.currentTopic!.id > 0) {
            chat.getTopicMembers(chat.currentTopic!.id).then((members) {
              final me = members.where(
                  (m) => m.id.toString() == auth.user?.id.toString());
              if (me.isNotEmpty && mounted) {
                setState(() {
                  _contextMenuIsAdmin = me.first.role == 'creator' ||
                      me.first.role == 'admin';
                });
              }
            });
          }
        },
      ));
    }

    return SmoothScrollView(
      controller: _messageScrollController,
      scrollSpeed: 1.0,
      reverse: true,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 96),
      child: Column(
        children: [
          // 分页加载指示器（显示在消息列表最上方）
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdwColors.blue,
                  ),
                ),
              ),
            ),
          ...messageWidgets,
        ],
      ),
    );
  }

  // ─── Mute Indicator ──────────────────────────────────────────────
  Widget _buildMuteIndicator() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AdwColors.window.withValues(alpha: 0.0),
              AdwColors.window,
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdwColors.red.withValues(alpha: 0.1),
            border: Border.all(color: AdwColors.red.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 14, color: AdwColors.red),
              SizedBox(width: 8),
              Text('您已被禁言',
                  style: TextStyle(color: AdwColors.red, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── New Message Indicator (右下角浮动按钮) ─────────────────────────
  Widget _buildNewMessageIndicator() {
    return Positioned(
      right: 24,
      bottom: 96,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _scrollToBottomAnimated();
              setState(() {
                _unreadCount = 0;
                _isAtBottom = true;
              });
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AdwColors.blue,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AdwColors.blue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '$_unreadCount 条新消息',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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

  // ─── Floating Input Footer ───────────────────────────────────────
  Widget _buildInputFooter(ChatProvider chat) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AdwColors.window.withValues(alpha: 0.0),
              AdwColors.window.withValues(alpha: 0.9),
              AdwColors.window,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 896),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuotingBar(),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (_, emoji) {
                          _inputController.text += emoji.emoji;
                          _inputController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _inputController.text.length),
                          );
                        },
                        config: Config(
                          emojiViewConfig: const EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 28,
                          ),
                          categoryViewConfig: const CategoryViewConfig(
                            backgroundColor: AdwColors.card,
                            indicatorColor: AdwColors.blue,
                            iconColor: AdwColors.fgDim,
                            iconColorSelected: AdwColors.blue,
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                          searchViewConfig: const SearchViewConfig(
                            backgroundColor: AdwColors.window,
                            hintText: '搜索表情...',
                          ),
                        ),
                      ),
                    ),
                  if (_showAttachmentMenu)
                    _buildAttachmentMenu(chat),
                  // ─── Mention list ──────────────────────────────
                  if (_showMentionList) _buildMentionList(),
                  Row(
                    children: [
                      _FooterIconButton(
                          icon: Icons.add,
                          onPressed: () => setState(() {
                            _showAttachmentMenu = !_showAttachmentMenu;
                            _showEmojiPicker = false;
                          })),
                      _FooterIconButton(
                          icon: _showEmojiPicker
                              ? Icons.emoji_emotions
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker ? AdwColors.blue : null,
                          onPressed: () => setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                            _showAttachmentMenu = false;
                          })),
                      _FooterIconButton(
                        icon: Icons.code,
                        color: _getModeIconColor(),
                        onPressed: _cycleMessageMode,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AdwColors.view.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AdwColors.border
                                    .withValues(alpha: 0.2)),
                          ),
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocusNode,
                            style: const TextStyle(
                                color: AdwColors.fg, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: _getPlaceholderText(chat),
                              hintStyle: const TextStyle(
                                  color: AdwColors.fgDim, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            maxLines: null,
                            onChanged: (val) => _handleInputChange(val, chat),
                            onSubmitted: (_) => _sendMessage(chat),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isSendingFile ? null : () => _sendMessage(chat),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getSendButtonColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: _isSendingFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Attachment Menu ───────────────────────────────────────────
  Widget _buildAttachmentMenu(ChatProvider chat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AdwColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdwColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AttachmentMenuItem(
            icon: Icons.image_outlined,
            label: '上传图片',
            color: const Color(0xFF2563EB),
            onTap: () => _pickAndSendFile(chat, 'image'),
          ),
          _AttachmentMenuItem(
            icon: Icons.videocam_outlined,
            label: '上传视频',
            color: const Color(0xFF7C3AED),
            onTap: () => _pickAndSendFile(chat, 'video'),
          ),
          _AttachmentMenuItem(
            icon: Icons.insert_drive_file_outlined,
            label: '上传文件',
            color: const Color(0xFF059669),
            onTap: () => _pickAndSendFile(chat, 'file'),
          ),
        ],
      ),
    );
  }

  // ─── Mention List ──────────────────────────────────────────────
  Widget _buildMentionList() {
    final filtered = _topicMembers
        .where((m) => m.username
            .toLowerCase()
            .contains(_mentionSearch.toLowerCase()))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: AdwColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdwColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              '选择成员',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AdwColors.fgDim,
              ),
            ),
          ),
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '无匹配成员',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdwColors.fgDim,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      return InkWell(
                        onTap: () => _handleSelectMention(member),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AdwColors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: getAvatarUrl(member.avatarUrl) != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: getAvatarUrl(member.avatarUrl)!,
                                            width: 24,
                                            height: 24,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Text(
                                              member.username.isNotEmpty
                                                  ? member.username[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AdwColors.blue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          member.username.isNotEmpty
                                              ? member.username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: AdwColors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  member.username,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AdwColors.fg,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Quoting Bar ───────────────────────────────────────────────
  Widget _buildQuotingBar() {
    if (_quotingMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 4),
      decoration: BoxDecoration(
        color: AdwColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AdwColors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote,
              size: 14, color: AdwColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回复 ${_quotingMessage!.senderName ?? '未知用户'}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AdwColors.accent),
                ),
                Text(
                  _quotingMessage!.content,
                  style: TextStyle(
                      fontSize: 12,
                      color: AdwColors.fg.withValues(alpha: 0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _quotingMessage = null),
            icon: const Icon(Icons.close, size: 14),
            color: AdwColors.fgDim,
            constraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ─── Footer icon button ─────────────────────────────────────────────
class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _FooterIconButton(
      {required this.icon, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color ?? AdwColors.fgDim,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ─── Attachment menu item ────────────────────────────────────────────
class _AttachmentMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AdwColors.fg)),
          ],
        ),
      ),
    );
  }
}

// ─── Discord-style message row ──────────────────────────────────────
class _DiscordStyleMessage extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isSameUser;
  final void Function(TapDownDetails details)? onAvatarTap;
  final void Function(TapDownDetails details)? onNameTap;
  final void Function(TapDownDetails details)? onContextMenu;

  const _DiscordStyleMessage({
    required this.message,
    required this.isMe,
    required this.isSameUser,
    this.onAvatarTap,
    this.onNameTap,
    this.onContextMenu,
  });

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    // Server-formatted strings (e.g. "2026年5月9日 22:13") pass through.
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(dateStr)) return dateStr;
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return dateStr;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (message.isRecalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 56),
            Icon(Icons.close,
                size: 14,
                color: AdwColors.fgDim.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text('[消息已被撤回]',
                style: TextStyle(
                    color: AdwColors.fgDim,
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    final timeStr = message.displayTime ?? _formatTime(message.createdAt);
    final senderName = message.senderName ?? '未知用户';
    final avatarUrl = getAvatarUrl(message.senderAvatar);

    return GestureDetector(
      onSecondaryTapDown: onContextMenu,
      onLongPressStart: onContextMenu != null
          ? (details) => onContextMenu!(TapDownDetails(
                globalPosition: details.globalPosition,
                localPosition: details.localPosition,
              ))
          : null,
      child: Padding(
        padding: EdgeInsets.only(top: isSameUser ? 2 : 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: !isSameUser
                  ? Center(
                      child: GestureDetector(
                        onTapDown: onAvatarTap,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AdwColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AdwColors.border
                                    .withValues(alpha: 0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _buildAvatarFallback(senderName),
                                )
                              : _buildAvatarFallback(senderName),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSameUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTapDown: onNameTap,
                              child: Text(
                                senderName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? AdwColors.accent
                                      : const Color(0xFF059669),
                                ),
                              ),
                            ),
                            if (message.senderIsBot) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BOT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(timeStr,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AdwColors.fgDim
                                        .withValues(alpha: 0.3))),
                          ],
                        ),
                      ),
                    _buildMessageContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: AdwColors.fgDim,
            fontWeight: FontWeight.bold,
            fontSize: 14),
      ),
    );
  }

  Widget _buildMessageContent() {
    final isEdited = message.messageType == 'edited';
    final subtype = message.messageSubtype ?? 'text';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEdited)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(Icons.edit,
                    size: 10,
                    color: AdwColors.fgDim.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('已编辑',
                    style: TextStyle(
                        fontSize: 10,
                        color: AdwColors.fgDim
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
        if (message.quotedMessage != null) _buildQuotedMessage(),
        _buildContentBySubtype(subtype),
      ],
    );
  }

  Widget _buildContentBySubtype(String subtype) {
    switch (subtype) {
      case 'image':
        return _buildImageMessage();
      case 'video':
        return _buildVideoMessage();
      case 'file':
        return _buildFileMessage();
      case 'markdown':
        return _buildMarkdownMessage();
      case 'html':
        return _buildHtmlMessage();
      default:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: AdwColors.fg.withValues(alpha: 0.9),
          ),
        );
    }
  }

  Widget _buildMarkdownMessage() {
    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 13.5, height: 1.5, color: AdwColors.fg.withValues(alpha: 0.9)),
        h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdwColors.fg),
        h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg),
        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdwColors.fg),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          backgroundColor: AdwColors.card.withValues(alpha: 0.6),
          color: AdwColors.fg,
        ),
        codeblockDecoration: BoxDecoration(
          color: AdwColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AdwColors.blue.withValues(alpha: 0.4), width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 8),
        a: const TextStyle(color: AdwColors.blue),
        strong: const TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fg),
        em: const TextStyle(fontStyle: FontStyle.italic, color: AdwColors.fg),
      ),
    );
  }

  Widget _buildHtmlMessage() {
    return Html(
      data: message.content,
      style: {
        'body': Style(
          fontSize: FontSize(13.5),
          lineHeight: LineHeight(1.5),
          color: AdwColors.fg.withValues(alpha: 0.9),
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'a': Style(color: AdwColors.blue),
        'code': Style(
          fontFamily: 'monospace',
          fontSize: FontSize(12),
          backgroundColor: AdwColors.card.withValues(alpha: 0.6),
        ),
        'pre': Style(
          backgroundColor: AdwColors.card.withValues(alpha: 0.5),
          padding: HtmlPaddings.all(8),
        ),
        'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.bold, color: AdwColors.fg),
        'h2': Style(fontSize: FontSize(18), fontWeight: FontWeight.bold, color: AdwColors.fg),
        'h3': Style(fontSize: FontSize(15), fontWeight: FontWeight.bold, color: AdwColors.fg),
        'blockquote': Style(
          border: const Border(left: BorderSide(color: AdwColors.blue, width: 3)),
          padding: HtmlPaddings.only(left: 8),
          fontStyle: FontStyle.italic,
        ),
      },
    );
  }

  Widget _buildImageMessage() {
    final rawUrl = message.resolvedFileUrl;
    String? imgSrc;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      imgSrc = rawUrl.startsWith('internal:')
          ? '${AppConfig.apiBase}/v1/proxy/$rawUrl'
          : (rawUrl.startsWith('http')
              ? rawUrl
              : '${AppConfig.apiBase}$rawUrl');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty &&
            message.content != '[图片消息]')
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(message.content,
                style: TextStyle(
                    fontSize: 13.5,
                    color: AdwColors.fg.withValues(alpha: 0.9))),
          ),
        if (imgSrc != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 320, maxHeight: 400),
              child: CachedNetworkImage(
                imageUrl: imgSrc,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdwColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('[图片加载失败]',
                      style: TextStyle(
                          color: AdwColors.fgDim, fontSize: 12)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          Text(message.content,
              style: TextStyle(
                  fontSize: 13.5,
                  color: AdwColors.fg.withValues(alpha: 0.9))),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdwColors.card.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AdwColors.border.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam,
                  size: 20, color: AdwColors.blue),
              const SizedBox(width: 8),
              const Text('[视频消息]',
                  style: TextStyle(
                      fontSize: 13, color: AdwColors.fgDim)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage() {
    final fileName =
        message.resolvedFileName ?? '未知文件';
    final fileSize = message.fileSize;
    final fileSizeStr = fileSize != null
        ? '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(message.content,
                style: TextStyle(
                    fontSize: 13.5,
                    color: AdwColors.fg.withValues(alpha: 0.9))),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdwColors.card.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AdwColors.border.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file,
                  size: 20, color: AdwColors.blue),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AdwColors.fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (fileSizeStr.isNotEmpty)
                      Text(fileSizeStr,
                          style: const TextStyle(
                              fontSize: 11, color: AdwColors.fgDim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.download,
                  size: 16, color: AdwColors.fgDim),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotedMessage() {
    final quoted = message.quotedMessage!;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: const Border(
          left: BorderSide(color: Colors.white24, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote,
                  size: 10, color: AdwColors.fgDim),
              const SizedBox(width: 4),
              Text('引用消息',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: AdwColors.fgDim
                          .withValues(alpha: 0.6))),
            ],
          ),
          if (quoted['username'] != null ||
              quoted['senderName'] != null)
            Text(
                quoted['username'] ??
                    quoted['senderName'] ??
                    'Unknown',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AdwColors.fg.withValues(alpha: 0.8))),
          Text(quoted['content'] ?? '',
              style: TextStyle(
                  fontSize: 11,
                  color: AdwColors.fg.withValues(alpha: 0.7)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

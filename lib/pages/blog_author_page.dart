import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../config.dart';
import '../models/blog.dart';
import '../providers/blog_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_client.dart';
import '../utils/json_helpers.dart';
import 'blog_detail_page.dart';

/// Author profile page — replicates blogweb/app/user/[id]
class BlogAuthorPage extends StatefulWidget {
  final int userId;
  final String? initialUsername;
  const BlogAuthorPage({super.key, required this.userId, this.initialUsername});

  @override
  State<BlogAuthorPage> createState() => _BlogAuthorPageState();
}

class _BlogAuthorPageState extends State<BlogAuthorPage> {
  Map<String, dynamic>? _userInfo;
  bool _loading = true;
  List<Blog> _blogs = [];
  List<Blog> _filteredBlogs = [];
  int? _selectedCategory;
  List<BlogCategory> _categories = [];
  bool _isFollowing = false;
  bool _followingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadUserInfo(),
      _loadBlogs(),
      _loadCategories(),
      _checkFollow(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUserInfo() async {
    try {
      final api = context.read<ApiClient>();
      final result = await api.request('/api/users/${widget.userId}/public');
      if (result.success && result.data != null) {
        setState(() => _userInfo = result.data as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _loadBlogs() async {
    final bp = context.read<BlogProvider>();
    await bp.getUserBlogs(widget.userId);
    if (mounted) {
      setState(() {
        _blogs = bp.userBlogs;
        _applyFilter();
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final bp = context.read<BlogProvider>();
      await bp.getCategories(widget.userId);
      if (mounted) setState(() => _categories = bp.categories);
    } catch (_) {}
  }

  Future<void> _checkFollow() async {
    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated || auth.user?.id == widget.userId) return;
      final friend = context.read<FriendProvider>();
      final result = await friend.checkFollowStatus(widget.userId);
      if (result.success && result.data != null) {
        final data = result.data as Map<String, dynamic>;
        setState(() => _isFollowing = data['isFollowing'] == true);
      }
    } catch (_) {}
  }

  void _applyFilter() {
    _filteredBlogs = _selectedCategory == null
        ? _blogs
        : _blogs.where((b) => b.categoryId == _selectedCategory).toList();
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    setState(() => _followingLoading = true);
    try {
      final friend = context.read<FriendProvider>();
      if (_isFollowing) {
        await friend.unfollowUser(widget.userId);
      } else {
        await friend.followUser(widget.userId);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {} finally {
      if (mounted) setState(() => _followingLoading = false);
    }
  }

  void _openBlogDetail(Blog blog) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<BlogProvider>.value(value: context.read<BlogProvider>()),
          ChangeNotifierProvider<AuthProvider>.value(value: context.read<AuthProvider>()),
        ],
        child: BlogDetailPage(blogId: blog.id, initialBlog: blog),
      ),
    ));
  }

  String? _resolveAvatar(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${AppConfig.apiBase}$url';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isSelf = context.read<AuthProvider>().user?.id == widget.userId;
    final username = _userInfo?['username'] as String? ?? widget.initialUsername ?? '...';
    return Scaffold(
      backgroundColor: AdwColors.window,
      appBar: AppBar(
        title: Text('$username 的博客', style: const TextStyle(color: AdwColors.fg)),
        backgroundColor: AdwColors.header,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AdwColors.fgDim),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AdwColors.accent))
          : _buildBody(isSelf, username),
    );
  }

  Widget _buildBody(bool isSelf, String username) {
    final avatar = _resolveAvatar(
        _userInfo?['avatarUrl'] as String? ?? _userInfo?['avatar_url'] as String?);
    final regDate = _userInfo?['registrationDate'] as String?;
    final regOrder = _userInfo?['registrationOrder'] as int?;
    final joinDur = _userInfo?['joinDuration'] as String?;
    final uid = _userInfo?['uid'] ?? widget.userId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Center(
          child: Column(children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: AdwColors.border.withValues(alpha: 0.2))),
              clipBehavior: Clip.antiAlias,
              child: avatar != null
                  ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(username))
                  : _avatarFallback(username),
            ),
            const SizedBox(height: 12),
            Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdwColors.fg)),
            Text('UID: $uid', style: const TextStyle(fontSize: 12, color: AdwColors.fgDim)),
          ]),
        ),
        const SizedBox(height: 12),
        if (!isSelf)
          Center(
            child: SizedBox(width: 140,
              child: OutlinedButton.icon(
                onPressed: _followingLoading ? null : _toggleFollow,
                icon: _followingLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AdwColors.accent))
                    : Icon(_isFollowing ? Icons.person_remove : Icons.person_add, size: 16),
                label: Text(_isFollowing ? '已关注' : '关注', style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdwColors.accent,
                  side: const BorderSide(color: AdwColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (regDate != null) _infoRow('注册', _fmt(regDate)),
        if (regOrder != null) _infoRow('第几位用户', '#$regOrder'),
        if (joinDur != null) _infoRow('加入时长', joinDur),
        const SizedBox(height: 20),
        // ── Categories ──
        if (_categories.isNotEmpty) ...[
          const Text('分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdwColors.fgDim)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(null, '全部', _selectedCategory == null),
            ..._categories.map((c) => _chip(c.id, c.name, _selectedCategory == c.id)),
          ]),
          const SizedBox(height: 16),
        ],
        // ── Blog list ──
        if (_filteredBlogs.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(48),
              child: Text('暂无文章', style: TextStyle(fontSize: 14, color: AdwColors.fgDim))))
        else
          ..._filteredBlogs.map((b) => _BlogItem(blog: b, onTap: () => _openBlogDetail(b))),
      ]),
    );
  }

  Widget _avatarFallback(String name) => Container(
    color: AdwColors.accent.withValues(alpha: 0.3),
    alignment: Alignment.center,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: AdwColors.accent, fontSize: 28, fontWeight: FontWeight.bold)),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AdwColors.fgDim)),
      const SizedBox(width: 8),
      Text(value, style: const TextStyle(fontSize: 13, color: AdwColors.fg)),
    ]),
  );

  Widget _chip(int? id, String name, bool selected) => GestureDetector(
    onTap: () => setState(() { _selectedCategory = id; _applyFilter(); }),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AdwColors.accent : AdwColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AdwColors.accent : AdwColors.border.withValues(alpha: 0.2)),
      ),
      child: Text(name, style: TextStyle(fontSize: 12,
          color: selected ? Colors.white : AdwColors.fgDim,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
    ),
  );

  String _fmt(String ds) {
    final dt = JsonHelpers.parseDateTime(ds);
    if (dt == null) return ds;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _BlogItem extends StatelessWidget {
  final Blog blog;
  final VoidCallback onTap;
  const _BlogItem({required this.blog, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(blog.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AdwColors.fg)),
        if ((blog.summary ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(blog.summary!, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AdwColors.fgDim)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          ...blog.tags.take(3).map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('#$t', style: const TextStyle(fontSize: 11, color: AdwColors.accent)),
          )),
          const Spacer(),
          Text(_fmt(blog.createdAt), style: const TextStyle(fontSize: 11, color: AdwColors.fgDim)),
          const SizedBox(width: 8),
          const Icon(Icons.favorite_border, size: 12, color: AdwColors.fgDim),
          const SizedBox(width: 2),
          Text('${blog.likeCount}', style: const TextStyle(fontSize: 11, color: AdwColors.fgDim)),
        ]),
      ]),
    ),
  );

  String _fmt(String? ds) {
    if (ds == null) return '';
    final dt = JsonHelpers.parseDateTime(ds);
    if (dt == null) return ds;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

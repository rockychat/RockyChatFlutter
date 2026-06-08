import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/blog_provider.dart';
import '../providers/auth_provider.dart';
import '../models/blog.dart';
import '../widgets/smooth_scroll_view.dart';
import '../utils/avatar.dart';
import '../utils/json_helpers.dart';
import 'blog_author_page.dart';

/// Blog detail page, mirroring blog-website/components/BlogDetailView.tsx.
class BlogDetailPage extends StatefulWidget {
  final int blogId;
  final Blog? initialBlog;

  const BlogDetailPage({
    super.key,
    required this.blogId,
    this.initialBlog,
  });

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  final _commentCtrl = TextEditingController();
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isSubmitting = false;


  Blog? get _blog =>
      context.read<BlogProvider>().currentBlog ?? widget.initialBlog;

  List<BlogComment> get _comments => context.read<BlogProvider>().comments;

  @override
  void initState() {
    super.initState();
    final blog = context.read<BlogProvider>();
    if (widget.initialBlog != null && widget.initialBlog!.id == widget.blogId) {
      _likeCount = widget.initialBlog!.likeCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) blog.setCurrentBlog(widget.initialBlog);
      });
    }
    _loadData();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final blogProvider = context.read<BlogProvider>();
    final auth = context.read<AuthProvider>();
    // Fetch full blog detail
    await blogProvider.getBlogById(widget.blogId);
    if (mounted && _blog != null) {
      setState(() {
        _likeCount = _blog!.likeCount;
      });
    }
    // Fetch comments
    await blogProvider.fetchComments(widget.blogId);

    // Check like status
    if (auth.isAuthenticated && auth.token != null) {
      final liked = await blogProvider.checkLikeStatus(widget.blogId);
      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) return;

    final blogProvider = context.read<BlogProvider>();
    // Optimistic update
    setState(() {
      if (_isLiked) {
        _likeCount--;
        _isLiked = false;
      } else {
        _likeCount++;
        _isLiked = true;
      }
    });

    if (_isLiked) {
      await blogProvider.likePost(widget.blogId);
    } else {
      await blogProvider.unlikePost(widget.blogId);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() => _isSubmitting = true);
    final blogProvider = context.read<BlogProvider>();
    final result = await blogProvider.createComment(widget.blogId, text);
    if (result.success) {
      _commentCtrl.clear();
      await blogProvider.fetchComments(widget.blogId);
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return dateStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final blog = _blog;

    if (blog == null) {
      return Scaffold(
        backgroundColor: AdwColors.window,
        appBar: _buildHeader(null),
        body: const Center(
          child: CircularProgressIndicator(color: AdwColors.accent),
        ),
      );
    }

    final tags = blog.tags;
    final contentType = blog.contentType ?? 'text';

    return Scaffold(
      backgroundColor: AdwColors.window,
      appBar: _buildHeader(blog),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return SmoothScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Author info ─────────────────────────────────
                    _buildAuthorSection(blog, contentType, isMobile),

                    const SizedBox(height: 16),
                    // ─── Title ───────────────────────────────────────
                    Text(
                      blog.title,
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        color: AdwColors.fg,
                        height: 1.3,
                      ),
                    ),
                const SizedBox(height: 24),

                // ─── Content ─────────────────────────────────────
                _buildContent(blog, contentType),

                // ─── Tags ────────────────────────────────────────
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildTags(tags),
                ],

                const SizedBox(height: 24),
                // ─── Actions (Like + Comment count) ──────────────
                _buildActions(auth),

                const SizedBox(height: 40),
                // ─── Comments Section ────────────────────────────
                _buildCommentsSection(auth),
              ],
            ),
          ),
        ),
      );
        },
      ),
    );
  }

  PreferredSizeWidget _buildHeader(Blog? blog) {
    return AppBar(
      title: Text(
        blog?.title ?? '博客详情',
        style: const TextStyle(fontSize: 16, color: AdwColors.fg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: AdwColors.header,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: AdwColors.fgDim),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          hoverColor: AdwColors.hover,
        ),
      ),
    );
  }

  Widget _buildAuthorSection(Blog blog, String contentType, bool isMobile) {
    final avatarUrl = getAvatarUrl(blog.authorAvatar ?? blog.userAvatar);

    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AdwColors.view,
            border: Border.all(color: AdwColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      (blog.username ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdwColors.fgDim,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    (blog.username ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdwColors.fgDim,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 16),
        // Name + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (blog.userId != null)
                    GestureDetector(
                      onTap: () {
                        final bp = context.read<BlogProvider>();
                        final ap = context.read<AuthProvider>();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MultiProvider(
                            providers: [
                              ChangeNotifierProvider<BlogProvider>.value(value: bp),
                              ChangeNotifierProvider<AuthProvider>.value(value: ap),
                            ],
                            child: BlogAuthorPage(
                                userId: blog.userId!,
                                initialUsername: blog.username),
                          ),
                        ));
                      },
                      child: Text(
                        blog.username ?? '匿名',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AdwColors.accent,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  else
                    Text(
                      blog.username ?? '匿名',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AdwColors.fg,
                        fontSize: 15,
                      ),
                    ),
                  if (contentType != 'text') ...[
                    const SizedBox(width: 8),
                    _ContentTypeBadge(type: contentType),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: AdwColors.fgDim),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(blog.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdwColors.fgDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Blog blog, String contentType) {
    switch (contentType) {
      case 'markdown':
        return MarkdownBody(
          data: blog.content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(
              fontSize: 16,
              color: AdwColors.fg,
              height: 1.7,
            ),
            h1: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AdwColors.fg,
            ),
            h2: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AdwColors.fg,
            ),
            h3: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AdwColors.fg,
            ),
            code: const TextStyle(
              backgroundColor: Color(0xFF374151),
              color: Color(0xFFF3F4F6),
              fontSize: 14,
            ),
            codeblockDecoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            blockquoteDecoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFF4B5563), width: 4)),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            a: const TextStyle(color: AdwColors.accent),
          ),
        );
      case 'html':
        // HTML content rendered as plain text with basic formatting
        return SelectableText(
          blog.content,
          style: const TextStyle(
            fontSize: 16,
            color: AdwColors.fg,
            height: 1.7,
          ),
        );
      default:
        return SelectableText(
          blog.content,
          style: const TextStyle(
            fontSize: 16,
            color: AdwColors.fg,
            height: 1.7,
          ),
        );
    }
  }

  Widget _buildTags(List<String> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AdwColors.view,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tag, size: 10, color: AdwColors.fgDim),
              const SizedBox(width: 4),
              Text(
                '#$tag',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdwColors.fgDim,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(AuthProvider auth) {
    final commentCount = _comments.length;

    return Row(
      children: [
        // Like button
        if (auth.isAuthenticated)
          Material(
            color: _isLiked ? AdwColors.fg : AdwColors.view,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: AdwColors.hover,
              onTap: _toggleLike,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: 18,
                      color: _isLiked ? AdwColors.window : AdwColors.fgDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_likeCount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isLiked ? AdwColors.window : AdwColors.fgDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AdwColors.view,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up, size: 18, color: AdwColors.fgDim),
                const SizedBox(width: 8),
                Text(
                  '$_likeCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdwColors.fgDim,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 16),
        // Comment count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AdwColors.view,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.message, size: 18, color: AdwColors.fgDim),
              const SizedBox(width: 8),
              Text(
                '$commentCount 评论',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AdwColors.fgDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '评论',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AdwColors.fg,
          ),
        ),
        const SizedBox(height: 16),

        // Comment form
        if (auth.isAuthenticated)
          _buildCommentForm(auth)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdwColors.view,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '登录后发表评论',
                style: TextStyle(color: AdwColors.accent, fontSize: 14),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Comment list
        ..._comments.map((comment) => _buildCommentItem(comment)),
      ],
    );
  }

  Widget _buildCommentForm(AuthProvider auth) {
    final user = auth.user;
    final avatarUrl = getAvatarUrl(user?.avatarUrl);

    Widget avatarWidget = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AdwColors.green,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null
          ? Image.network(avatarUrl, fit: BoxFit.cover)
          : Center(
              child: Text(
                (user?.username ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
    );

    Widget inputWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          style: const TextStyle(color: AdwColors.fg, fontSize: 14),
          decoration: InputDecoration(
            hintText: '写下你的评论...',
            hintStyle: const TextStyle(color: AdwColors.fgDim, fontSize: 14),
            filled: true,
            fillColor: AdwColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdwColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdwColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdwColors.accent),
            ),
            contentPadding: const EdgeInsets.all(12),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (_isSubmitting || _commentCtrl.text.trim().isEmpty)
              ? null
              : _submitComment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdwColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AdwColors.accent.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('发布评论', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdwColors.view,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdwColors.border),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth < 400) {
            // Mobile: stack vertically
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatarWidget,
                const SizedBox(height: 10),
                inputWidget,
              ],
            );
          }
          // Desktop: side by side
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatarWidget,
              const SizedBox(width: 12),
              Expanded(child: inputWidget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommentItem(BlogComment comment) {
    final avatarUrl = getAvatarUrl(comment.avatarUrl ?? comment.userAvatar);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AdwColors.view,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      comment.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AdwColors.fgDim,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AdwColors.fg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdwColors.fgDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AdwColors.fg,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// Content type badge, mirroring ContentTypeBadge in BlogDetailView.tsx.
class _ContentTypeBadge extends StatelessWidget {
  final String type;
  const _ContentTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    Color bgColor;
    Color fgColor;

    switch (type) {
      case 'markdown':
        icon = Icons.code;
        label = 'Markdown';
        bgColor = const Color(0x338B5CF6);
        fgColor = const Color(0xFFC4B5FD);
        break;
      case 'html':
        icon = Icons.description;
        label = 'HTML';
        bgColor = const Color(0x33F97316);
        fgColor = const Color(0xFFFDBA74);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fgColor),
          ),
        ],
      ),
    );
  }
}

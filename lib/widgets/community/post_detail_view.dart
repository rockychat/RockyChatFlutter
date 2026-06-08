import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/community_provider.dart';
import '../../models/comment.dart';
import '../../utils/avatar.dart';
import '../../utils/json_helpers.dart';

class PostDetailView extends StatefulWidget {
  final int postId;
  final VoidCallback onBack;
  const PostDetailView({super.key, required this.postId, required this.onBack});
  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  final _commentCtrl = TextEditingController();
  List<Comment> _comments = [];
  bool _submitting = false;
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cp = context.read<CommunityProvider>();
      cp.fetchPostDetails(widget.postId);
      cp.fetchComments(widget.postId).then((c) { if (mounted) setState(() => _comments = c); });
    });
  }

  void _checkLike() {
    final cp = context.read<CommunityProvider>();
    final post = cp.currentPost;
    if (post != null) {
      _likeCount = post.likeCount;
      cp.checkLikeStatus(widget.postId).then((r) {
        if (r.success && mounted) {
          final data = r.data as Map<String, dynamic>? ?? {};
          setState(() => _isLiked = data['isLiked'] == true);
        }
      });
    }
  }

  Future<void> _toggleLike() async {
    final cp = context.read<CommunityProvider>();
    if (_isLiked) {
      setState(() { _isLiked = false; _likeCount--; });
      await cp.unlikePost(widget.postId);
    } else {
      setState(() { _isLiked = true; _likeCount++; });
      await cp.likePost(widget.postId);
    }
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final cp = context.read<CommunityProvider>();
    final result = await cp.createComment(widget.postId, _commentCtrl.text.trim());
    if (result.success) {
      _commentCtrl.clear();
      final c = await cp.fetchComments(widget.postId);
      if (mounted) setState(() => _comments = c);
    }
    if (mounted) setState(() => _submitting = false);
  }

  String _fmtDate(String? s) {
    if (s == null) return '';
    final d = JsonHelpers.parseDateTime(s);
    if (d == null) return s;
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  String _fmtShort(String? s) {
    if (s == null) return '';
    final d = JsonHelpers.parseDateTime(s);
    if (d == null) return s;
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(builder: (ctx, cp, _) {
      final post = cp.currentPost;
      if (cp.loading && post == null) return const Center(child: CircularProgressIndicator(color: AdwColors.accent));
      if (post != null && _likeCount == 0 && !_isLiked) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkLike());
      }
      if (post == null) return const SizedBox();
      final authorAvatar = getAvatarUrl(post.authorAvatar ?? post.userAvatar);

      return Scaffold(
        backgroundColor: AdwColors.window,
        body: Column(children: [
        // Header bar
        Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 22, color: AdwColors.fg)),
            const SizedBox(width: 4),
            Expanded(child: Text(post.communityName ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdwColors.fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),

        // Content
        Expanded(child: SmoothScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Author
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: AdwColors.view,
              backgroundImage: authorAvatar != null ? CachedNetworkImageProvider(authorAvatar) : null,
              child: authorAvatar == null ? Text((post.authorName ?? post.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: AdwColors.fgDim, fontSize: 16)) : null),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.authorName ?? post.username ?? '匿名', style: const TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fg)),
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: AdwColors.fgDim),
                const SizedBox(width: 4),
                Text(_fmtDate(post.createdAt), style: const TextStyle(fontSize: 11, color: AdwColors.fgDim)),
              ]),
            ]),
          ]),
          const SizedBox(height: 20),

          // Title
          Text(post.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AdwColors.fg)),
          const SizedBox(height: 18),

          // Content
          Text(post.content, style: const TextStyle(fontSize: 15, color: AdwColors.fg, height: 1.7)),
          const SizedBox(height: 16),

          // Tags
          if (post.tags != null && post.tags!.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: post.tags!.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AdwColors.view, borderRadius: BorderRadius.circular(999)),
              child: Text('#$t', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdwColors.fgDim)),
            )).toList()),
          if (post.tags != null && post.tags!.isNotEmpty) const SizedBox(height: 16),

          // Like & comment counts
          Row(children: [
            GestureDetector(
              onTap: _toggleLike,
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _isLiked ? AdwColors.fg : AdwColors.view, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.thumb_up, size: 18, color: _isLiked ? AdwColors.window : AdwColors.fgDim),
                  const SizedBox(width: 6),
                  Text('$_likeCount', style: TextStyle(fontWeight: FontWeight.bold, color: _isLiked ? AdwColors.window : AdwColors.fgDim)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Row(children: [
              const Icon(Icons.chat_bubble_outline, size: 18, color: AdwColors.fgDim),
              const SizedBox(width: 6),
              Text('${_comments.length} 评论', style: const TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fgDim)),
            ]),
          ]),
          const SizedBox(height: 28),

          // Comments section
          const Text('评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg)),
          const SizedBox(height: 16),

          // New comment
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 18, backgroundColor: AdwColors.view, child: Icon(Icons.person, size: 18, color: AdwColors.fgDim)),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              TextField(controller: _commentCtrl, maxLines: 3, style: const TextStyle(color: AdwColors.fg, fontSize: 14),
                decoration: InputDecoration(hintText: '写下你的评论...', filled: true, fillColor: AdwColors.view,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.accent)),
                  contentPadding: const EdgeInsets.all(14))),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: ElevatedButton(
                onPressed: _submitting ? null : _submitComment,
                style: ElevatedButton.styleFrom(backgroundColor: AdwColors.fg, foregroundColor: AdwColors.window, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                child: Text(_submitting ? '...' : '发布评论', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              )),
            ])),
          ]),
          const SizedBox(height: 24),

          // Comment list
          ..._comments.map((c) {
            final cAvatar = getAvatarUrl(c.userAvatar);
            return Padding(padding: const EdgeInsets.only(bottom: 18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 18, backgroundColor: AdwColors.view,
                backgroundImage: cAvatar != null ? CachedNetworkImageProvider(cAvatar) : null,
                child: cAvatar == null ? Text((c.username ?? '?')[0].toUpperCase(), style: const TextStyle(color: AdwColors.fgDim, fontSize: 12)) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(c.username ?? '匿名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdwColors.fg)),
                  const SizedBox(width: 8),
                  Text(_fmtShort(c.createdAt), style: const TextStyle(fontSize: 11, color: AdwColors.fgDim)),
                ]),
                const SizedBox(height: 4),
                Text(c.content, style: const TextStyle(fontSize: 14, color: AdwColors.fg)),
              ])),
            ]));
          }),
        ])),
      ),
    ]),
    );
  });
  }
}

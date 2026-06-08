import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/community_provider.dart';
import '../../utils/avatar.dart';
import '../../utils/json_helpers.dart';
import '../../pages/create_post_page.dart';

class CommunityDetail extends StatefulWidget {
  final int communityId;
  final VoidCallback onBack;
  final void Function(int) onNavigatePost;
  const CommunityDetail({super.key, required this.communityId, required this.onBack, required this.onNavigatePost});
  @override
  State<CommunityDetail> createState() => _CommunityDetailState();
}

class _CommunityDetailState extends State<CommunityDetail> {
  int? _activeSubsection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 使用 Provider.of 并设置 listen: false
        final cp = Provider.of<CommunityProvider>(context, listen: false);
        cp.fetchCommunityDetails(widget.communityId);
        cp.fetchSubsections(widget.communityId);
        cp.fetchCommunityPosts(widget.communityId);
      }
    });
  }

  void _onSubsectionChange(int? subId) {
    setState(() => _activeSubsection = subId);
    final cp = Provider.of<CommunityProvider>(context, listen: false);
    cp.fetchCommunityPosts(widget.communityId, subsectionId: subId);
  }

  Future<void> _handleJoinLeave() async {
    final cp = Provider.of<CommunityProvider>(context, listen: false);
    final community = cp.currentCommunity;
    if (community == null) return;
    if (community.userRole != null) {
      final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        backgroundColor: AdwColors.dialog, title: const Text('确认'), content: const Text('确定要退出此社区吗？'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定'))],
      ));
      if (confirm == true) await cp.leaveCommunity(widget.communityId);
    } else {
      await cp.joinCommunity(widget.communityId);
    }
  }

  void _navigateToCreatePost() {
  final cp = Provider.of<CommunityProvider>(context, listen: false);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cp),
        ],
        child: CreatePostPage(
          communityId: widget.communityId,
          subsections: cp.subsections,
          onSuccess: () => cp.fetchCommunityPosts(widget.communityId, subsectionId: _activeSubsection),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    // 使用 Provider.of 并设置 listen: true 来监听变化
    final cp = Provider.of<CommunityProvider>(context, listen: true);
    final community = cp.currentCommunity;
    
    if (cp.loading && community == null) {
      return const Scaffold(
        backgroundColor: AdwColors.window,
        body: Center(child: CircularProgressIndicator(color: AdwColors.accent)),
      );
    }
    if (community == null) return const SizedBox();
    final avatar = getAvatarUrl(community.avatarUrl);

    return Scaffold(
      backgroundColor: AdwColors.window,
      body: Stack(children: [
        Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 28, 28, 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 24, color: AdwColors.fg)),
            const SizedBox(width: 12),
            CircleAvatar(radius: 34, backgroundColor: AdwColors.view,
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null ? Text(community.name.isNotEmpty ? community.name[0].toUpperCase() : '?', style: const TextStyle(color: AdwColors.fgDim, fontSize: 26, fontWeight: FontWeight.bold)) : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(community.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AdwColors.fg)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.people, size: 14, color: AdwColors.fgDim),
                const SizedBox(width: 4),
                Text('${community.memberCount} 成员', style: const TextStyle(fontSize: 13, color: AdwColors.fgDim)),
                if (community.description != null && community.description!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(community.description!, style: TextStyle(fontSize: 13, color: AdwColors.fgDim.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ])),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleJoinLeave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: community.userRole != null ? AdwColors.card : AdwColors.fg,
                  borderRadius: BorderRadius.circular(999),
                  border: community.userRole != null ? Border.all(color: AdwColors.border) : null,
                ),
                child: Text(community.userRole != null ? '已加入' : '加入社区',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: community.userRole != null ? AdwColors.fg : AdwColors.window)),
              ),
            ),
          ])),

          // Subsection tabs
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 28), children: [
            _TabButton(label: '全部', active: _activeSubsection == null, onTap: () => _onSubsectionChange(null)),
            ...cp.subsections.map((sub) => _TabButton(label: sub.name, active: _activeSubsection == sub.id, onTap: () => _onSubsectionChange(sub.id))),
          ])),
          const SizedBox(height: 8),

          // Posts
          Expanded(child: cp.communityPosts.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 64, height: 64, decoration: BoxDecoration(color: AdwColors.view, shape: BoxShape.circle, border: Border.all(color: AdwColors.border)),
                  child: Icon(Icons.forum, size: 28, color: AdwColors.fgDim.withValues(alpha: 0.5))),
                const SizedBox(height: 14),
                const Text('此分区暂无帖子。', style: TextStyle(color: AdwColors.fgDim)),
                TextButton(onPressed: _navigateToCreatePost, child: const Text('发布第一个帖子', style: TextStyle(fontWeight: FontWeight.bold))),
              ]))
            : SmoothScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(cp.communityPosts.length, (i) {
                  final post = cp.communityPosts[i];
                  return GestureDetector(
                    onTap: () => widget.onNavigatePost(post.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: AdwColors.card, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(post.authorName ?? post.username ?? '匿名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdwColors.fg)),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AdwColors.fgDim, fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(_formatDate(post.createdAt), style: const TextStyle(fontSize: 11, color: AdwColors.fgDim)),
                          if (post.subsectionName != null) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: AdwColors.fgDim, fontSize: 12)),
                            const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AdwColors.view, borderRadius: BorderRadius.circular(999)),
                              child: Text(post.subsectionName!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdwColors.fgDim, letterSpacing: 0.5))),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg)),
                        const SizedBox(height: 6),
                        Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AdwColors.fgDim, height: 1.4)),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.thumb_up_outlined, size: 15, color: AdwColors.fgDim),
                          const SizedBox(width: 4),
                          Text('${post.likeCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdwColors.fgDim)),
                          const SizedBox(width: 18),
                          const Icon(Icons.chat_bubble_outline, size: 15, color: AdwColors.fgDim),
                          const SizedBox(width: 4),
                          Text('${post.commentCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdwColors.fgDim)),
                        ]),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
        ]),

        // FAB
        if (community.userRole != null)
          Positioned(bottom: 28, right: 28, child: GestureDetector(
            onTap: _navigateToCreatePost,
            child: Container(width: 52, height: 52, decoration: const BoxDecoration(color: AdwColors.fg, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]),
              child: const Icon(Icons.tag, size: 24, color: AdwColors.window)),
          )),
      ]),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = JsonHelpers.parseDateTime(dateStr);
    if (d == null) return dateStr;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: Container(
          margin: const EdgeInsets.only(right: 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? AdwColors.fg : AdwColors.fgDim)),
            const SizedBox(height: 6),
            Container(height: 3,
              decoration: BoxDecoration(color: active ? AdwColors.fg : Colors.transparent, borderRadius: BorderRadius.circular(999))),
          ]),
        ),
      ),
    );
  }
}

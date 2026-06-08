import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/community_provider.dart';
import '../../models/community.dart';
import '../../utils/avatar.dart';
import 'create_community_modal.dart';

class CommunityHome extends StatefulWidget {
  final void Function(int) onNavigateCommunity;
  const CommunityHome({super.key, required this.onNavigateCommunity});
  @override
  State<CommunityHome> createState() => _CommunityHomeState();
}

class _CommunityHomeState extends State<CommunityHome> {
  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 避免在 build 阶段触发 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cp = Provider.of<CommunityProvider>(context, listen: false);
        cp.fetchRecommendedCommunities();
        cp.fetchMyCommunities();
      }
    });
  }

  void _showCreateModal() {
    showDialog(context: context, builder: (_) => const CreateCommunityModal());
  }

  @override
  Widget build(BuildContext context) {
    // 使用 Provider.of 并设置 listen: true 来监听变化
    final cp = Provider.of<CommunityProvider>(context, listen: true);
    
    return SmoothScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('社区', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AdwColors.fg)),
                SizedBox(height: 6),
                Text('发现并加入你感兴趣的社区。', style: TextStyle(fontSize: 14, color: AdwColors.fgDim)),
              ])),
              GestureDetector(
                onTap: _showCreateModal,
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: AdwColors.fg, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: AdwColors.window, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 28),

            // Recommended
            Row(children: const [
              Icon(Icons.people, size: 20, color: AdwColors.accent),
              SizedBox(width: 8),
              Text('推荐社区', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg)),
            ]),
            const SizedBox(height: 14),
            if (cp.recommendedCommunities.isEmpty && !cp.loading)
              const Padding(padding: EdgeInsets.only(bottom: 20), child: Text('暂无推荐。', style: TextStyle(color: AdwColors.fgDim, fontSize: 13, fontStyle: FontStyle.italic)))
            else
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cp.recommendedCommunities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => _RecommendedCard(
                    community: cp.recommendedCommunities[i],
                    onTap: () => widget.onNavigateCommunity(cp.recommendedCommunities[i].id),
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // My Communities
            Row(children: const [
              Icon(Icons.tag, size: 20, color: AdwColors.green),
              SizedBox(width: 8),
              Text('我的社区', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg)),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 4 : constraints.maxWidth > 600 ? 3 : constraints.maxWidth > 400 ? 2 : 1;
              final items = <Widget>[
                ...cp.myCommunities.map((c) => _MyCommunityCard(
                  community: c,
                  onTap: () => widget.onNavigateCommunity(c.id),
                )),
                _CreateCard(onTap: _showCreateModal),
              ];
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: items.map((w) => SizedBox(
                  width: (constraints.maxWidth - 14 * (cols - 1)) / cols,
                  child: w,
                )).toList(),
              );
            }),
          ]),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  const _RecommendedCard({required this.community, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatar = getAvatarUrl(community.avatarUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AdwColors.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AdwColors.view,
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null
                  ? Text(
                      community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AdwColors.fgDim, fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                community.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdwColors.fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${community.memberCount} 成员',
                style: const TextStyle(fontSize: 11, color: AdwColors.fgDim),
              ),
            ])),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              community.description ?? '暂无描述',
              style: const TextStyle(fontSize: 13, color: AdwColors.fg, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

class _MyCommunityCard extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  const _MyCommunityCard({required this.community, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatar = getAvatarUrl(community.avatarUrl);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AdwColors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AdwColors.view,
            backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null
                ? Text(
                    community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AdwColors.fgDim, fontSize: 18, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              community.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${community.memberCount} 成员',
              style: const TextStyle(fontSize: 11, color: AdwColors.fgDim),
            ),
          ])),
        ]),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AdwColors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AdwColors.border, width: 2, strokeAlign: BorderSide.strokeAlignInside),
            ),
            child: const Icon(Icons.add, size: 24, color: AdwColors.fgDim),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
            Text('创建社区', style: TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fg)),
            Text('开始一个新的社区', style: TextStyle(fontSize: 11, color: AdwColors.fgDim)),
          ])),
        ]),
      ),
    );
  }
}

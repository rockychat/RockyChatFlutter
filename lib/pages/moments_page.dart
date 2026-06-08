import 'package:flutter/material.dart';
import '../widgets/smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/moment_provider.dart';
import '../models/moment.dart';
import 'create_moment_page.dart';

/// Moments page with Square/Following/Friends tabs.
/// PC: right side has create moment panel, no FAB
/// Mobile: FAB to open create moment page
class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _loadTab(_tabCtrl.index);
      }
    });
    // 使用 addPostFrameCallback 避免在 build 阶段调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTab(0);
      }
    });
  }

  void _loadTab(int index) {
    final moment = context.read<MomentProvider>();
    switch (index) {
      case 0:
        moment.getPublicMoments();
        break;
      case 1:
        moment.getFollowingMoments();
        break;
      case 2:
        moment.getFriendMoments();
        break;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ─── Desktop Layout: Feed + Create Panel ─────────────────────────
  Widget _buildDesktopLayout() {
    return Consumer<MomentProvider>(
      builder: (context, moment, _) {
        return Row(
          children: [
            // Left: Feed area
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _MomentFeed(
                          moments: moment.publicMoments,
                          loading: moment.loading,
                          isDesktop: true,
                        ),
                        _MomentFeed(
                          moments: moment.followingMoments,
                          loading: moment.loading,
                          isDesktop: true,
                        ),
                        _MomentFeed(
                          moments: moment.friendMoments,
                          loading: moment.loading,
                          isDesktop: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(width: 1, color: AdwColors.border.withValues(alpha: 0.3)),
            // Right: Create Moment Panel
            SizedBox(
              width: 320,
              child: _CreateMomentPanel(
                onSuccess: () => _loadTab(_tabCtrl.index),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Mobile Layout: Feed + FAB ───────────────────────────────────
  Widget _buildMobileLayout() {
    return Consumer<MomentProvider>(
      builder: (context, moment, _) {
        return Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _MomentFeed(
                        moments: moment.publicMoments,
                        loading: moment.loading,
                        isDesktop: false,
                      ),
                      _MomentFeed(
                        moments: moment.followingMoments,
                        loading: moment.loading,
                        isDesktop: false,
                      ),
                      _MomentFeed(
                        moments: moment.friendMoments,
                        loading: moment.loading,
                        isDesktop: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // FAB for mobile
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                onPressed: () => _navigateToCreatePage(),
                backgroundColor: AdwColors.accent,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AdwColors.header,
        border: Border(bottom: BorderSide(color: AdwColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdwColors.view.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AdwRadius.sm),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AdwColors.card,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AdwColors.fg,
                unselectedLabelColor: AdwColors.fgDim,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: '广场'),
                  Tab(text: '关注'),
                  Tab(text: '好友'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCreatePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateMomentPage(
          onSuccess: () => _loadTab(_tabCtrl.index),
        ),
      ),
    );
  }
}

// ─── Moment Feed (List with divider style) ─────────────────────────
class _MomentFeed extends StatelessWidget {
  final List<Moment> moments;
  final bool loading;
  final bool isDesktop;

  const _MomentFeed({
    required this.moments,
    required this.loading,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && moments.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AdwColors.accent));
    }

    if (moments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_satisfied_alt,
                size: 48, color: AdwColors.fgDim.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无动态',
                style: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.4),
                    fontSize: 14)),
          ],
        ),
      );
    }

    return SmoothScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          moments.length,
          (i) => _MomentListItem(
            moment: moments[i],
            isDesktop: isDesktop,
          ),
        ),
      ),
    );
  }
}

// ─── Moment List Item (Divider style, no card) ─────────────────────
class _MomentListItem extends StatelessWidget {
  final Moment moment;
  final bool isDesktop;

  const _MomentListItem({required this.moment, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AdwColors.accent.withValues(alpha: 0.3),
                child: Text(
                  (moment.username ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info row
                    Row(
                      children: [
                        Text(moment.username ?? '未知用户',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AdwColors.fg)),
                        const SizedBox(width: 8),
                        if (moment.createdAt != null)
                          Text(_formatTime(moment.createdAt!),
                              style: const TextStyle(
                                  fontSize: 11, color: AdwColors.fgDim)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Content
                    Text(moment.content,
                        style: const TextStyle(
                            fontSize: 14, color: AdwColors.fg, height: 1.5)),
                    const SizedBox(height: 8),
                    // Actions
                    Row(
                      children: [
                        _ActionBtn(
                          icon: moment.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: '${moment.likeCount}',
                          color: moment.isLiked ? AdwColors.red : AdwColors.fgDim,
                          onTap: () {
                            final mp = context.read<MomentProvider>();
                            if (moment.isLiked) {
                              mp.unlikeMoment(moment.id);
                            } else {
                              mp.likeMoment(moment.id);
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        _ActionBtn(
                          icon: Icons.chat_bubble_outline,
                          label: '${moment.commentCount}',
                          color: AdwColors.fgDim,
                          onTap: () {
                            // TODO: show comments
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Divider line (not a card)
        Divider(
          height: 1,
          thickness: 1,
          color: AdwColors.border.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr); // moments API uses standard ISO format
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return '';
    }
  }
}

// ─── Action Button ─────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop Create Moment Panel ───────────────────────────────────
class _CreateMomentPanel extends StatefulWidget {
  final VoidCallback onSuccess;
  const _CreateMomentPanel({required this.onSuccess});

  @override
  State<_CreateMomentPanel> createState() => _CreateMomentPanelState();
}

class _CreateMomentPanelState extends State<_CreateMomentPanel> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<MomentProvider>().createMoment(content);
      _contentController.clear();
      widget.onSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发布成功'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发布失败，请重试'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '发布动态',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AdwColors.fg,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AdwColors.view,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _contentController,
              maxLines: 6,
              style: const TextStyle(color: AdwColors.fg, fontSize: 14),
              decoration: InputDecoration(
                hintText: '分享你的想法...',
                hintStyle: TextStyle(color: AdwColors.fgDim.withValues(alpha: 0.6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdwColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('发布', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

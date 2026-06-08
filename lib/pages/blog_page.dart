import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/smooth_scroll_view.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/blog_provider.dart';
import '../providers/auth_provider.dart';
import '../models/blog.dart';
import '../utils/json_helpers.dart';
import '../pages/create_blog_page.dart';
import '../pages/blog_detail_page.dart';
import '../pages/blog_author_page.dart';


/// Blog page with Discover / My Blogs views.
/// Mirrors blog-website/app/page.tsx layout.
class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  void _navigateToBlogDetail(BuildContext context, Blog blog) {
    final blogProvider = context.read<BlogProvider>();
    final authProvider = context.read<AuthProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<BlogProvider>.value(value: blogProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: BlogDetailPage(blogId: blog.id, initialBlog: blog),
        ),
      ),
    );
  }

  void _navigateToCreateBlog(BuildContext context, VoidCallback onSuccess) {
    final blogProvider = context.read<BlogProvider>();
    final authProvider = context.read<AuthProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<BlogProvider>.value(value: blogProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: CreateBlogPage(onSuccess: onSuccess),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _BlogContent(
          onNavigateToBlogDetail: (blog) => _navigateToBlogDetail(context, blog),
          onNavigateToCreateBlog: (onSuccess) => _navigateToCreateBlog(context, onSuccess),
        ),
      ],
    );
  }
}

class _BlogContent extends StatefulWidget {
  final void Function(Blog) onNavigateToBlogDetail;
  final void Function(VoidCallback) onNavigateToCreateBlog;

  const _BlogContent({
    required this.onNavigateToBlogDetail,
    required this.onNavigateToCreateBlog,
  });

  @override
  State<_BlogContent> createState() => _BlogContentState();
}

class _BlogContentState extends State<_BlogContent> {
  String _viewMode = 'discover';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<Blog>? _searchResults;
  String _activeSearchQuery = '';

  // 热门标签（与 Next.js 一致）
  static const _popularTags = [
    '技术', '生活', '编程', '设计',
    '人工智能', '开源', '旅行', '美食',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBlogs();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadBlogs() {
    final blog = context.read<BlogProvider>();
    final auth = context.read<AuthProvider>();
    if (_viewMode == 'discover') {
      blog.getBlogs();
    } else if (auth.user != null) {
      blog.getUserBlogs(auth.user!.id);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _activeSearchQuery = '';
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _activeSearchQuery = query;
    });
    final blog = context.read<BlogProvider>();
    await blog.searchBlogs(query);
    if (mounted) {
      setState(() {
        _searchResults = List.from(blog.blogs);
        _isSearching = false;
      });
    }
  }

  void _onTagTap(String tag) {
    _searchCtrl.text = tag;
    _onSearchChanged(tag);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchResults = null;
      _activeSearchQuery = '';
      _isSearching = false;
    });
    _loadBlogs();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Consumer<BlogProvider>(
      builder: (context, blog, _) {
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final isMobile = constraints.maxWidth < 768;

            if (isMobile) {
              return _buildMobileLayout(blog, auth);
            }
            return _buildDesktopLayout(blog, auth);
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(BlogProvider blog, AuthProvider auth) {
    return Row(
      children: [
        _buildDesktopSidebar(blog, auth),
        Container(width: 1, color: AdwColors.border),
        Expanded(
          child: _buildMainContent(blog),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar(BlogProvider blog, AuthProvider auth) {
    return Container(
      width: 240,
      color: AdwColors.sidebar,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdwColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Blog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdwColors.fg)),
                IconButton(
                  onPressed: _loadBlogs,
                  icon: Icon(Icons.refresh, size: 14,
                      color: blog.loading ? AdwColors.accent : AdwColors.fgDim),
                  tooltip: 'Refresh',
                  style: IconButton.styleFrom(hoverColor: AdwColors.hover),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _SidebarItem(
                    icon: Icons.explore, label: 'Discover',
                    isSelected: _viewMode == 'discover',
                    onTap: () => _switchView('discover'),
                  ),
                  const SizedBox(height: 4),
                  _SidebarItem(
                    icon: Icons.menu_book, label: 'My Blogs',
                    isSelected: _viewMode == 'my-blogs',
                    onTap: () => _switchView('my-blogs'),
                  ),
                ],
              ),
            ),
          ),
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onNavigateToCreateBlog(() => _loadBlogs()),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdwColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BlogProvider blog, AuthProvider auth) {
    final blogs = _viewMode == 'discover' ? blog.blogs : blog.userBlogs;
    final displayBlogs = _searchResults ?? blogs;
    final hasSearch = _activeSearchQuery.isNotEmpty;
    final noResults = _searchResults != null && _searchResults!.isEmpty;

    return SmoothScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + New Post button
          Row(
            children: [
              const Text('最新文章',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdwColors.fg)),
              const Spacer(),
              if (auth.isAuthenticated)
                IconButton(
                  onPressed: () => widget.onNavigateToCreateBlog(() => _loadBlogs()),
                  icon: const Icon(Icons.add, color: AdwColors.accent),
                  style: IconButton.styleFrom(backgroundColor: AdwColors.view),
                  tooltip: 'New Post',
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMobileTabBar(),
          const SizedBox(height: 12),
          _buildMobileSearch(),
          const SizedBox(height: 12),
          _buildMobileTags(),
          const SizedBox(height: 16),
          _buildBlogList(blog, displayBlogs, hasSearch, noResults),
        ],
      ),
    );
  }

  Widget _buildMobileTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AdwColors.view,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MobileTab(
              label: 'Discover', icon: Icons.explore,
              isSelected: _viewMode == 'discover',
              onTap: () => _switchView('discover'),
            ),
          ),
          Expanded(
            child: _MobileTab(
              label: 'My Blogs', icon: Icons.menu_book,
              isSelected: _viewMode == 'my-blogs',
              onTap: () => _switchView('my-blogs'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearch() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      style: const TextStyle(color: AdwColors.fg, fontSize: 14),
      decoration: InputDecoration(
        hintText: '搜索文章...',
        hintStyle: const TextStyle(color: AdwColors.fgDim, fontSize: 14),
        prefixIcon: const Icon(Icons.search, size: 18, color: AdwColors.fgDim),
        suffixIcon: _activeSearchQuery.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _clearSearch)
            : null,
        filled: true,
        fillColor: AdwColors.view,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
        isDense: true,
      ),
    );
  }

  Widget _buildMobileTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _popularTags.map((tag) {
        return Material(
          color: AdwColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onTagTap(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AdwColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(tag,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AdwColors.fgDim)),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _switchView(String mode) {
    if (_viewMode == mode) return;
    setState(() {
      _viewMode = mode;
      _searchResults = null;
      _activeSearchQuery = '';
    });
    _searchCtrl.clear();
    _loadBlogs();
  }

  Widget _buildMainContent(BlogProvider blog) {
    final blogs = _viewMode == 'discover' ? blog.blogs : blog.userBlogs;
    final displayBlogs = _searchResults ?? blogs;
    final hasSearch = _activeSearchQuery.isNotEmpty;
    final noResults = _searchResults != null && _searchResults!.isEmpty;

    return SmoothScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───────────────────────────────────────
          Text(
            '最新文章',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: AdwColors.fg),
          ),
          const SizedBox(height: 4),
          const Text(
            '当你感到迷茫的时候，不妨合并一下XiongDa BigCow的PR吧',
            style: TextStyle(fontSize: 14, color: AdwColors.fgDim),
          ),
          const SizedBox(height: 24),

          // ─── Two-column layout ────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 900;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: blog list
                  Expanded(
                    child: _buildBlogList(blog, displayBlogs, hasSearch, noResults),
                  ),
                  // Right: sidebar (search + tags) – only on wide screens
                  if (isWide) ...[
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 280,
                      child: _buildRightSidebar(),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBlogList(
    BlogProvider blog,
    List<Blog> displayBlogs,
    bool hasSearch,
    bool noResults,
  ) {
    // Loading state
    if (blog.loading && displayBlogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(color: AdwColors.accent),
        ),
      );
    }

    // Searching state
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AdwColors.fgDim),
              ),
              SizedBox(width: 8),
              Text('搜索中...', style: TextStyle(color: AdwColors.fgDim, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // No search results
    if (noResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(64),
          child: Column(
            children: [
              const Text('🔍', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                '未找到与"$_activeSearchQuery"相关的文章',
                style: const TextStyle(color: AdwColors.fgDim, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _clearSearch,
                style: TextButton.styleFrom(
                  backgroundColor: AdwColors.view,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('清除搜索'),
              ),
            ],
          ),
        ),
      );
    }

    // Search result count
    final searchHeader = (hasSearch && displayBlogs.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '搜索 "$_activeSearchQuery" 找到 ${displayBlogs.length} 篇文章',
              style: const TextStyle(fontSize: 13, color: AdwColors.fgDim),
            ),
          )
        : null;

    // Empty state
    if (displayBlogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 48, color: AdwColors.fgDim),
            const SizedBox(height: 12),
            const Text('暂无博客', style: TextStyle(color: AdwColors.fgDim, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?searchHeader,
        ...displayBlogs.map((blogItem) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _BlogCard(
            blog: blogItem,
            onTap: () => widget.onNavigateToBlogDetail(blogItem),
          ),
        )),
      ],
    );
  }

  Widget _buildRightSidebar() {
    return Column(
      children: [
        // Search box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdwColors.view,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdwColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AdwColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索文章标题或内容...',
                  hintStyle: const TextStyle(color: AdwColors.fgDim, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AdwColors.fgDim),
                  filled: true,
                  fillColor: AdwColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                  isDense: true,
                ),
              ),
              if (_activeSearchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: _clearSearch,
                    child: const Text(
                      '清除搜索',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdwColors.fgDim,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Popular tags
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdwColors.view,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdwColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tag, size: 16, color: AdwColors.accent),
                  SizedBox(width: 8),
                  Text(
                    '热门标签',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdwColors.fg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularTags.map((tag) {
                  return Material(
                    color: AdwColors.card,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      hoverColor: AdwColors.accent.withValues(alpha: 0.15),
                      onTap: () => _onTagTap(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: AdwColors.border),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AdwColors.fgDim,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Sidebar Item ─────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AdwColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(AdwRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdwRadius.sm),
        hoverColor: AdwColors.hover,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? AdwColors.fg : AdwColors.fgDim),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AdwColors.fg : AdwColors.fgDim)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Blog Card (matching BlogCard.tsx) ────────────────────────────
class _BlogCard extends StatelessWidget {
  final Blog blog;
  final VoidCallback onTap;

  const _BlogCard({required this.blog, required this.onTap});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = JsonHelpers.parseDateTime(dateStr);
    if (dt == null) return dateStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tags = blog.tags;
    final displayTags = tags.take(3).toList();
    final overflowCount = tags.length > 3 ? tags.length - 3 : 0;
    final summary = blog.summary ?? blog.content;
    final dateStr = _formatDate(blog.createdAt);

    return Material(
      color: AdwColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        hoverColor: AdwColors.hover,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AdwColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      blog.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdwColors.fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Preview
                    Text(
                      summary.length > 200 ? '${summary.substring(0, 200)}...' : summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdwColors.fgDim,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Meta row
                    Row(
                      children: [
                        const Icon(Icons.person, size: 12, color: AdwColors.fgDim),
                        const SizedBox(width: 4),
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
                                  fontSize: 11,
                                  color: AdwColors.accent,
                                  decoration: TextDecoration.underline),
                            ),
                          )
                        else
                          Text(blog.username ?? '匿名',
                              style: const TextStyle(
                                  fontSize: 11, color: AdwColors.fgDim)),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, size: 10, color: AdwColors.fgDim),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: AdwColors.fgDim)),
                      ],
                    ),
                    // Tags
                    if (displayTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...displayTags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdwColors.hover,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AdwColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag, size: 8, color: AdwColors.fgDim),
                                const SizedBox(width: 3),
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AdwColors.fgDim,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          if (overflowCount > 0)
                            Text(
                              '+$overflowCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AdwColors.fgDim,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right: read hint (hidden on narrow screens)
              LayoutBuilder(
                builder: (ctx, constraints) {
                  if (constraints.maxWidth < 500) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: const Text(
                      '阅读文章 →',
                      style: TextStyle(fontSize: 13, color: AdwColors.fgDim),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Tab ──────────────────────────────────────────────────
class _MobileTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AdwColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: isSelected ? AdwColors.accent : AdwColors.fgDim),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AdwColors.fg : AdwColors.fgDim,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

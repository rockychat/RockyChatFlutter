import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../services/route_observer.dart';
import '../utils/about_dialog.dart';
import 'chat_page.dart';
import 'moments_page.dart';
import 'community_page.dart';
import 'blog_page.dart';
import 'friends_page.dart';

/// Main shell with desktop sidebar (NavigationRail) or mobile bottom nav.
/// Bottom bar hides automatically when route stack depth > 1.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  
  // 是否显示底栏/侧边栏（当路由栈深度为1时显示）
  bool _showBottomBar = true;

  static const _navItems = [
    _NavItem(Icons.chat_bubble_rounded, '聊天'),
    _NavItem(Icons.people_alt_rounded, '好友'),
    _NavItem(Icons.public_rounded, '动态'),
    _NavItem(Icons.forum_rounded, '社区'),
    _NavItem(Icons.article_rounded, '博客'),
  ];

  @override
  void initState() {
    super.initState();
    // 监听路由变化
    appRouteObserver.addListener(_onRouteChanged);
    _updateBottomBarVisibility();
  }

  @override
  void dispose() {
    appRouteObserver.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    _updateBottomBarVisibility();
  }

  void _updateBottomBarVisibility() {
    final shouldHide = appRouteObserver.routeStackDepth > 1;
    if (_showBottomBar == !shouldHide) return;
    if (mounted) {
      setState(() {
        _showBottomBar = !shouldHide;
      });
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const ChatPage();
      case 1:
        return const FriendsPage();
      case 2:
        return const MomentsPage();
      case 3:
        return const CommunityPage();
      case 4:
        return const BlogPage();
      default:
        return const ChatPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // ─── Desktop: Sidebar (可隐藏) ───────────────────────────────
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AdwColors.window,
      body: Row(
        children: [
          // Sidebar - 根据 _showBottomBar 显隐
          if (_showBottomBar)
            Container(
              width: 72,
              color: AdwColors.sidebar,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ...List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final isSelected = _selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: Material(
                        color: isSelected
                            ? AdwColors.selected
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AdwRadius.sm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AdwRadius.sm),
                          hoverColor: AdwColors.hover,
                          onTap: () {
                            setState(() => _selectedIndex = i);
                          },
                          child: SizedBox(
                            width: 56,
                            height: 52,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? AdwColors.accent
                                      : AdwColors.fgDim,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? AdwColors.fg
                                        : AdwColors.fgDim,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  // 菜单按钮
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: PopupMenuButton<_MenuAction>(
                      offset: const Offset(0, -60),
                      color: AdwColors.popover,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AdwRadius.sm),
                        side: const BorderSide(color: AdwColors.border),
                      ),
                      icon: const Icon(Icons.menu, size: 22, color: AdwColors.fgDim),
                      tooltip: '菜单',
                      style: IconButton.styleFrom(
                        hoverColor: AdwColors.hover,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AdwRadius.sm),
                        ),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case _MenuAction.about:
                            showAppAboutDialog(context);
                            break;
                          case _MenuAction.logout:
                            context.read<AuthProvider>().logout();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _MenuAction.about,
                          child: ListTile(
                            leading: Icon(Icons.info_outline, color: AdwColors.fgDim, size: 20),
                            title: Text('关于', style: TextStyle(color: AdwColors.fg, fontSize: 14)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MenuAction.logout,
                          child: ListTile(
                            leading: Icon(Icons.logout, color: AdwColors.fgDim, size: 20),
                            title: Text('退出登录', style: TextStyle(color: AdwColors.fg, fontSize: 14)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          // 内容区域
          Expanded(
            child: _buildPage(_selectedIndex),
          ),
        ],
      ),
    );
  }

  // ─── Mobile: BottomNavigationBar (可隐藏) ─────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AdwColors.window,
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: _showBottomBar
          ? Container(
              decoration: const BoxDecoration(
                color: AdwColors.header,
                border: Border(top: BorderSide(color: AdwColors.border, width: 1)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (i) {
                  setState(() => _selectedIndex = i);
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                selectedItemColor: AdwColors.accent,
                unselectedItemColor: AdwColors.fgDim,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                elevation: 0,
                items: _navItems
                    .map((item) => BottomNavigationBarItem(
                          icon: Icon(item.icon),
                          label: item.label,
                        ))
                    .toList(),
              ),
            )
          : null,
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

enum _MenuAction { about, logout }

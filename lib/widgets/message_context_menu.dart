import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/message.dart';

/// Message context menu matching web/components/MessageContextMenu.jsx.
/// Shows on right-click (desktop) / long-press (mobile).
/// Items: Copy, Edit (owner), Forward, Quote, Revoke (owner/admin)
class MessageContextMenu extends StatelessWidget {
  final Offset position;
  final Message message;
  final bool isMessageOwner;
  final bool isTopicAdmin;
  final VoidCallback onClose;
  final void Function(String content) onCopy;
  final void Function(Message message)? onEdit;
  final void Function(Message message) onRevoke;
  final void Function(List<Message> messages) onForward;
  final void Function(Message message) onQuote;

  const MessageContextMenu({
    super.key,
    required this.position,
    required this.message,
    required this.isMessageOwner,
    this.isTopicAdmin = false,
    required this.onClose,
    required this.onCopy,
    this.onEdit,
    required this.onRevoke,
    required this.onForward,
    required this.onQuote,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final canEdit = isMessageOwner;
    final canRevoke = isMessageOwner || isTopicAdmin;
    
    // Keep within screen bounds (web: Math.min logic)
    double left = position.dx;
    double top = position.dy;
    const menuWidth = 200.0;
    const menuHeight = 300.0;
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
    }
    left = left.clamp(8.0, screenSize.width - menuWidth);
    top = top.clamp(8.0, screenSize.height - menuHeight);

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            onSecondaryTap: onClose,
            child: const SizedBox.expand(),
          ),
        ),
        // Menu
        Positioned(
          left: left,
          top: top,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.95 + 0.05 * value,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  // web: bg-white/95 dark:bg-[#242424]/95 backdrop-blur-xl
                  color: const Color(0xF2242424), // ~95% opacity
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy
                      _MenuItem(
                        icon: Icons.copy,
                        label: '复制',
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: message.content));
                          onCopy(message.content);
                          onClose();
                        },
                      ),
                      // Edit (only message owner)
                      if (canEdit)
                        _MenuItem(
                          icon: Icons.edit,
                          label: '编辑',
                          onTap: () {
                            onEdit?.call(message);
                            onClose();
                          },
                        ),
                      // Forward
                      _MenuItem(
                        icon: Icons.share,
                        label: '转发',
                        onTap: () {
                          onForward([message]);
                          onClose();
                        },
                      ),
                      // Quote
                      _MenuItem(
                        icon: Icons.format_quote,
                        label: '引用',
                        onTap: () {
                          onQuote(message);
                          onClose();
                        },
                      ),
                      // Revoke (owner or admin)
                      if (canRevoke) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        _MenuItem(
                          icon: Icons.delete_outline,
                          label: '撤回',
                          isDestructive: true,
                          onTap: () {
                            onRevoke(message);
                            onClose();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AdwColors.red : AdwColors.fg;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: isDestructive
          ? AdwColors.red.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }
}

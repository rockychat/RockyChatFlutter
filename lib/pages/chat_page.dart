import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/chat_area.dart';
import 'chat_detail_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isDetailOpen = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;

            if (isDesktop) {
              return Row(
                children: [
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: AdwColors.window,
                      border: Border(
                        right: BorderSide(
                          color: AdwColors.border.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const ChatSidebar(),
                  ),
                  Expanded(
                    child: ChatArea(
                      onBack: () => chat.resetSelection(),
                    ),
                  ),
                ],
              );
            } else {
              if (_isDetailOpen) {
                return Container(color: AdwColors.window);
              }

              if (chat.activeChatType != 'none') {
                _isDetailOpen = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _pushChatDetail(context);
                });
                return Container(color: AdwColors.window);
              }

              return Container(
                color: AdwColors.window,
                child: const ChatSidebar(),
              );
            }
          },
        );
      },
    );
  }

  void _pushChatDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatDetailPage(),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isDetailOpen = false);
        context.read<ChatProvider>().resetSelection();
      }
    });
  }
}

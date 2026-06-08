import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_area.dart';

/// Full-screen chat detail page for mobile.
/// Pushed via Navigator.push so it has NO bottom navigation bar.
class ChatDetailPage extends StatelessWidget {
  const ChatDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdwColors.window,
      body: ChatArea(
        onBack: () {
          final chat = context.read<ChatProvider>();
          chat.resetSelection();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

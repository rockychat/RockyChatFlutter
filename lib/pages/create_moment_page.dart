import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/moment_provider.dart';
import '../providers/auth_provider.dart';

/// Independent page for creating a new moment (mobile only).
class CreateMomentPage extends StatefulWidget {
  final VoidCallback onSuccess;
  const CreateMomentPage({super.key, required this.onSuccess});

  @override
  State<CreateMomentPage> createState() => _CreateMomentPageState();
}

class _CreateMomentPageState extends State<CreateMomentPage> {
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final momentProvider = context.read<MomentProvider>();
      await momentProvider.createMoment(content);
      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (_) {
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
    final userName = _resolveUserName();

    return Scaffold(
      backgroundColor: AdwColors.window,
      appBar: AppBar(
        title: const Text('发布动态',
            style: TextStyle(color: AdwColors.fg)),
        backgroundColor: AdwColors.header,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AdwColors.fgDim),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: AdwColors.accent,
                backgroundColor: Colors.transparent,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdwColors.accent,
                      ),
                    )
                  : const Text('发布',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AdwColors.accent.withValues(alpha: 0.3),
                  child: Text(
                    userName.isNotEmpty
                        ? userName[0].toUpperCase()
                        : '我',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AdwColors.fg,
                      ),
                    ),
                    const Text(
                      '公开',
                      style: TextStyle(
                          fontSize: 12, color: AdwColors.fgDim),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                autofocus: true,
                style: const TextStyle(
                    color: AdwColors.fg, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '分享你的想法...',
                  hintStyle: TextStyle(
                    color: AdwColors.fgDim.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveUserName() {
    // AuthProvider is guaranteed to exist in the tree (provided by
    // _ServicesShell in main.dart).
    try {
      final auth = context.read<AuthProvider>();
      final name = auth.user?.username;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // Gracefully handle edge cases where AuthProvider is not available.
    }
    return '我';
  }
}

// lib/pages/create_post_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/community_provider.dart';
import '../models/community.dart';

class CreatePostPage extends StatefulWidget {
  final int communityId;
  final List<Subsection> subsections;
  final VoidCallback onSuccess;

  const CreatePostPage({
    super.key,
    required this.communityId,
    required this.subsections,
    required this.onSuccess,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  int? _subsectionId;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      setState(() => _error = '请填写标题和内容');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final cp = context.read<CommunityProvider>();
    final result = await cp.createPost({
      'community_id': widget.communityId,
      'title': _titleCtrl.text.trim(),
      'content': _contentCtrl.text.trim(),
      if (_subsectionId != null) 'subsection_id': _subsectionId,
    });
    if (result.success) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _error = result.message ?? '发布失败';
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdwColors.window,
      appBar: AppBar(
        title: const Text('发布帖子', style: TextStyle(color: AdwColors.fg)),
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
              onPressed: _submitting ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: AdwColors.accent,
              ),
              child: _submitting
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AdwColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AdwColors.red, fontSize: 13)),
              ),
            TextField(
              controller: _titleCtrl,
              maxLength: 200,
              style: const TextStyle(
                  color: AdwColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '标题',
                filled: true,
                fillColor: AdwColors.view,
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
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl,
              maxLength: 5000,
              maxLines: 10,
              style: const TextStyle(color: AdwColors.fg, fontSize: 15),
              decoration: InputDecoration(
                hintText: '正文内容 (支持 Markdown)...',
                filled: true,
                fillColor: AdwColors.view,
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
                contentPadding: const EdgeInsets.all(16),
                alignLabelWithHint: true,
              ),
            ),
            if (widget.subsections.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('选择分区 (可选)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AdwColors.fgDim,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.subsections.map((sub) {
                  final selected = _subsectionId == sub.id;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _subsectionId = selected ? null : sub.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AdwColors.fg : AdwColors.view,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : AdwColors.border),
                      ),
                      child: Text(
                        sub.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: selected ? AdwColors.window : AdwColors.fgDim,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

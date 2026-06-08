import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/community_provider.dart';
import '../../models/community.dart';

class CreatePostModal extends StatefulWidget {
  final int communityId;
  final List<Subsection> subsections;
  final VoidCallback onSuccess;

  const CreatePostModal({super.key, required this.communityId, required this.subsections, required this.onSuccess});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  int? _subsectionId;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) return;
    setState(() { _submitting = true; _error = null; });
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
      setState(() { _error = result.message ?? '发布失败'; _submitting = false; });
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdwColors.window,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdwColors.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('发布帖子', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdwColors.fg)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AdwColors.fgDim)),
            ]),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AdwColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: AdwColors.red, fontSize: 13)),
              ),
            TextField(
              controller: _titleCtrl, maxLength: 200,
              style: const TextStyle(color: AdwColors.fg, fontSize: 17, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '标题', filled: true, fillColor: AdwColors.view,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.accent)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentCtrl, maxLength: 5000, maxLines: 6,
              style: const TextStyle(color: AdwColors.fg, fontSize: 14),
              decoration: InputDecoration(
                hintText: '正文内容 (支持 Markdown)...', filled: true, fillColor: AdwColors.view,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.accent)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            if (widget.subsections.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('选择分区 (可选)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdwColors.fgDim, letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: widget.subsections.map((sub) {
                final selected = _subsectionId == sub.id;
                return GestureDetector(
                  onTap: () => setState(() => _subsectionId = selected ? null : sub.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AdwColors.fg : AdwColors.view,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? Colors.transparent : AdwColors.border),
                    ),
                    child: Text(sub.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? AdwColors.window : AdwColors.fgDim)),
                  ),
                );
              }).toList()),
            ],
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fgDim))),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submitting || _titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AdwColors.fg, foregroundColor: AdwColors.window, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                child: Text(_submitting ? '发布中...' : '发布', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

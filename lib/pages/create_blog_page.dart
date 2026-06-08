import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/blog_provider.dart';

class CreateBlogPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const CreateBlogPage({super.key, required this.onSuccess});

  @override
  State<CreateBlogPage> createState() => _CreateBlogPageState();
}

class _CreateBlogPageState extends State<CreateBlogPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];
  String _contentType = 'markdown'; // text, markdown, html
  bool _submitting = false;
  String? _error;

  static const _contentTypes = [
    {'value': 'markdown', 'label': 'Markdown', 'icon': Icons.code},
    {'value': 'html', 'label': 'HTML', 'icon': Icons.description},
    {'value': 'text', 'label': '纯文本', 'icon': Icons.text_fields},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = '请填写标题');
      return;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = '请填写内容');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final bp = context.read<BlogProvider>();
    final result = await bp.createBlog({
      'title': _titleCtrl.text.trim(),
      'content': _contentCtrl.text.trim(),
      'tags': _tags,
      'content_type': _contentType,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdwColors.window,
      appBar: AppBar(
        title: const Text('发布博客', style: TextStyle(color: AdwColors.fg)),
        backgroundColor: AdwColors.header,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AdwColors.fgDim),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdwColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AdwColors.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AdwColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdwColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: AdwColors.red, fontSize: 13)),
                  ),

                // Content type selector
                const Text(
                  '内容类型',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AdwColors.fg,
                  ),
                ),
                const SizedBox(height: 8),
                _buildContentTypeSelector(),
                const SizedBox(height: 20),

                // Title
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

                // Tags input
                const Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AdwColors.fg,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTagsInput(),
                const SizedBox(height: 12),

                // Content
                TextField(
                  controller: _contentCtrl,
                  maxLength: 50000,
                  maxLines: 15,
                  style: const TextStyle(color: AdwColors.fg, fontSize: 15, height: 1.5),
                  decoration: InputDecoration(
                    hintText: _contentType == 'markdown'
                        ? '正文内容 (支持 Markdown)...'
                        : '正文内容...',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _contentTypes.map((ct) {
        final isSelected = _contentType == ct['value'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ct['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : AdwColors.fgDim,
                ),
                const SizedBox(width: 6),
                Text(ct['label'] as String),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _contentType = ct['value'] as String);
              }
            },
            selectedColor: AdwColors.accent,
            backgroundColor: AdwColors.view,
            side: BorderSide(
              color: isSelected ? AdwColors.accent : AdwColors.border,
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AdwColors.fgDim,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tags display
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 12, color: AdwColors.fgDim),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AdwColors.fgDim),
                  onDeleted: () => _removeTag(tag),
                  backgroundColor: AdwColors.view,
                  side: const BorderSide(color: AdwColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),
        // Tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                style: const TextStyle(color: AdwColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '添加标签...',
                  hintStyle: const TextStyle(color: AdwColors.fgDim, fontSize: 14),
                  filled: true,
                  fillColor: AdwColors.view,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AdwColors.view,
                foregroundColor: AdwColors.fgDim,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AdwColors.border),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../providers/community_provider.dart';

class CreateCommunityModal extends StatefulWidget {
  const CreateCommunityModal({super.key});

  @override
  State<CreateCommunityModal> createState() => _CreateCommunityModalState();
}

class _CreateCommunityModalState extends State<CreateCommunityModal> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'public';
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() { _submitting = true; _error = null; });
    final cp = context.read<CommunityProvider>();
    final result = await cp.createCommunity({
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'type': _type,
      'join_policy': 'open',
    });
    if (result.success) {
      if (mounted) Navigator.pop(context);
    } else {
      setState(() { _error = result.message ?? '创建社区失败'; _submitting = false; });
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdwColors.window,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AdwColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text('创建社区', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdwColors.fg)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AdwColors.fgDim)),
            ]),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AdwColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: AdwColors.red, fontSize: 13)),
              ),
            TextField(
              controller: _nameCtrl, maxLength: 100,
              style: const TextStyle(color: AdwColors.fg),
              decoration: InputDecoration(
                labelText: '社区名称', hintText: '例如：技术交流',
                filled: true, fillColor: AdwColors.view,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl, maxLength: 500, maxLines: 3,
              style: const TextStyle(color: AdwColors.fg),
              decoration: InputDecoration(
                labelText: '描述', hintText: '介绍一下这个社区...',
                filled: true, fillColor: AdwColors.view,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdwColors.accent)),
              ),
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdwColors.fg))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _typeButton('public', Icons.public, '公开')),
              const SizedBox(width: 12),
              Expanded(child: _typeButton('private', Icons.lock, '私有')),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(fontWeight: FontWeight.bold, color: AdwColors.fgDim))),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submitting || _nameCtrl.text.trim().isEmpty ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AdwColors.fg, foregroundColor: AdwColors.window, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4),
                child: Text(_submitting ? '创建中...' : '创建', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _typeButton(String value, IconData icon, String label) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AdwColors.accent : AdwColors.view,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : AdwColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: selected ? Colors.white : AdwColors.fgDim),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? Colors.white : AdwColors.fg)),
        ]),
      ),
    );
  }
}

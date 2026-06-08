import 'package:flutter/material.dart';
import '../theme.dart';

/// 显示关于弹窗，展示应用信息和字体说明。
void showAppAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AdwColors.dialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdwRadius.normal),
        side: const BorderSide(color: AdwColors.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: AdwColors.accent, size: 22),
          SizedBox(width: 12),
          Text(
            '关于',
            style: TextStyle(
              color: AdwColors.fg,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '花枫咖啡馆',
            style: TextStyle(
              color: AdwColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Rocky Chat',
            style: TextStyle(color: AdwColors.fgDim, fontSize: 13),
          ),
          SizedBox(height: 12),
          Text(
            '版本：1.0.0',
            style: TextStyle(color: AdwColors.fgSecondary, fontSize: 13),
          ),
          SizedBox(height: 16),
          Text(
            '本应用默认使用 HarmonyOS Sans 字体，'
            '由华为设计的一款开源无衬线字体，'
            '覆盖简体中文、繁体中文、拉丁文等多种语言，'
            '风格简洁现代，阅读体验舒适。',
            style: TextStyle(color: AdwColors.fgDim, fontSize: 13, height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

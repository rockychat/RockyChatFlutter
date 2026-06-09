import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 模仿 React 端 GnomeTopBar 左上角的点线按钮。
///
/// - 由 [itemCount] 个点组成，当前选中项为长条，其余为圆点。
/// - 鼠标滚轮可切换选中项（300ms 防抖，10px 死区）。
/// - 点击按钮触发 [onRefresh]（刷新当前页面到初始状态）。
class ActivitiesButton extends StatefulWidget {
  final int selectedIndex;
  final int itemCount;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onRefresh;

  const ActivitiesButton({
    super.key,
    required this.selectedIndex,
    required this.itemCount,
    required this.onIndexChanged,
    required this.onRefresh,
  });

  @override
  State<ActivitiesButton> createState() => _ActivitiesButtonState();
}

class _ActivitiesButtonState extends State<ActivitiesButton> {
  DateTime _lastWheelTime = DateTime(2000);

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy.abs() < 10) return;

    final now = DateTime.now();
    if (now.difference(_lastWheelTime).inMilliseconds < 300) return;
    _lastWheelTime = now;

    if (dy > 0 && widget.selectedIndex < widget.itemCount - 1) {
      widget.onIndexChanged(widget.selectedIndex + 1);
    } else if (dy < 0 && widget.selectedIndex > 0) {
      widget.onIndexChanged(widget.selectedIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onRefresh,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.1),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.itemCount, (i) {
                  final isSelected = widget.selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 20.0 : 5.0,
                      height: 5.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.75),
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:universal_io/io.dart' show Platform;

class SmoothScrollView extends StatefulWidget {
  final ScrollController? controller;
  final Widget child;
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final int durationMS;
  final double scrollSpeed;
  final double scrollbarWidth;
  final Color scrollbarColor;
  final Color scrollbarHoverColor;

  const SmoothScrollView({
    super.key,
    this.controller,
    required this.child,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.durationMS = 200,
    this.scrollSpeed = 1.0,
    this.scrollbarWidth = 6,
    this.scrollbarColor = Colors.transparent,
    this.scrollbarHoverColor = Colors.transparent,
  });

  @override
  State<SmoothScrollView> createState() => _SmoothScrollViewState();
}

/// 移动端默认物理效果
const _kMobilePhysics = BouncingScrollPhysics();

/// 桌面端禁用原生滚动，完全由 Listener 接管
const _kDesktopPhysics = NeverScrollableScrollPhysics();

class _SmoothScrollViewState extends State<SmoothScrollView> {
  late ScrollController _controller;

  /// 当前滚动物理效果（桌面/移动动态切换）
  ScrollPhysics _physics = _kDesktopPhysics;

  /// 目标滚动位置
  /// 每次滚轮事件往上累加 delta，animateTo 会平滑过渡到这个位置
  double _futurePosition = 0;

  /// 标记鼠标滚轮动画是否正在进行中
  /// 当此标记为 true 时，controller listener 不会同步 _futurePosition，
  /// 避免打断连续滚轮事件的累积效果
  bool _isMouseScrolling = false;

  /// 鼠标滚轮动画结束后的重置定时器
  Timer? _mouseScrollResetTimer;

  // 滚动条拖动相关
  bool _isDraggingScrollbar = false;
  double _dragStartOffset = 0;
  double _dragStartScrollOffset = 0;

  bool get _isDesktopOrWeb {
    return !Platform.isAndroid && !Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_onControllerUpdate);
  }

  /// ScrollController 位置变化回调
  /// 关键：当不是由鼠标滚轮驱动时，同步 _futurePosition 到当前实际位置
  /// 这保证外部调用 jumpTo / animateTo 后，下次鼠标滚轮从正确位置开始
  void _onControllerUpdate() {
    if (!_isMouseScrolling && _controller.hasClients) {
      _futurePosition = _controller.offset;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SmoothScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onControllerUpdate);
      _controller = widget.controller ?? ScrollController();
      _controller.addListener(_onControllerUpdate);
      // 重置同步状态
      if (_controller.hasClients) {
        _futurePosition = _controller.offset;
      }
    }
  }

  @override
  void dispose() {
    _mouseScrollResetTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// 处理桌面端鼠标滚轮
  void _onPointerSignal(PointerSignalEvent event) {
    if (!_isDesktopOrWeb) return;
    if (_isDraggingScrollbar) return;

    // 如果当前是移动端物理，切换到桌面端物理
    if (_physics != _kDesktopPhysics) {
      _physics = _kDesktopPhysics;
      if (_controller.hasClients) {
        _futurePosition = _controller.offset;
      }
      setState(() {});
      return;
    }

    if (event is PointerScrollEvent) {
      if (!_controller.hasClients) return;

      final maxExtent = _controller.position.maxScrollExtent;

      // 边界检测：如果已经到边缘且还要继续同方向滚动，就不处理
      // reverse 模式下边界方向相反
      if (_controller.position.atEdge) {
        final dy = event.scrollDelta.dy;
        if (widget.reverse) {
          if (_controller.position.pixels <= 0 && dy > 0) return;
          if (_controller.position.pixels >= maxExtent && dy < 0) return;
        } else {
          if (_controller.position.pixels <= 0 && dy < 0) return;
          if (_controller.position.pixels >= maxExtent && dy > 0) return;
        }
      }

      // 标记为鼠标滚轮驱动，阻止 controller listener 同步 _futurePosition
      _isMouseScrolling = true;

      // 核心：直接将 scrollDelta 累加到 futurePosition
      // reverse 模式下取反 delta，保持视觉方向一致
      final rawDelta = widget.scrollDirection == Axis.vertical
          ? event.scrollDelta.dy * widget.scrollSpeed
          : event.scrollDelta.dx * widget.scrollSpeed;
      final delta = widget.reverse ? -rawDelta : rawDelta;

      _futurePosition += delta;
      // 夹紧到有效范围
      _futurePosition = _futurePosition.clamp(0.0, maxExtent);

      // 用 animateTo 平滑过渡到目标位置
      // 使用 Curves.linear 让连续滚动事件之间的衔接最平滑
      // Flutter 的 animateTo 会自动中断上一个动画并从当前位置开始新动画
      _controller.animateTo(
        _futurePosition,
        duration: Duration(milliseconds: widget.durationMS),
        curve: Curves.linear,
      );

      // 动画结束后重置 _isMouseScrolling 标记
      // 加一点缓冲时间确保动画完全结束
      _mouseScrollResetTimer?.cancel();
      _mouseScrollResetTimer = Timer(
        Duration(milliseconds: widget.durationMS + 50),
        () {
          _isMouseScrolling = false;
          // 动画结束后最终同步一次
          if (_controller.hasClients) {
            _futurePosition = _controller.offset;
          }
        },
      );
    }
  }

  /// 处理触摸输入 —— 切换到移动端物理效果
  void _onPointerDown(PointerDownEvent event) {
    if (_physics != _kMobilePhysics) {
      setState(() {
        _physics = _kMobilePhysics;
      });
    }
    // 触摸后同步 futurePosition，这样下次鼠标滚轮可以从正确位置开始
    _isMouseScrolling = false;
    _mouseScrollResetTimer?.cancel();
    if (_controller.hasClients) {
      _futurePosition = _controller.offset;
    }
  }

  // ─── 透明滚动条（保留交互但不可见）─────────────────────────────────────────────

  (double top, double height, bool visible) _getScrollbarGeometry() {
    if (!_controller.hasClients) return (0, 0, false);

    final position = _controller.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) return (0, 0, false);

    final viewportHeight = position.viewportDimension;
    // reverse 模式：position 0 = 底部，scrollRatio 需要反转
    final rawRatio = position.pixels / maxExtent;
    final scrollRatio = widget.reverse ? (1 - rawRatio) : rawRatio;
    final thumbHeight =
        (viewportHeight / (maxExtent + viewportHeight)) * viewportHeight;
    final thumbTop = scrollRatio * (viewportHeight - thumbHeight);

    return (thumbTop, thumbHeight.clamp(30.0, viewportHeight), true);
  }

  void _startScrollbarDrag(DragStartDetails details) {
    if (!_controller.hasClients) return;
    _isDraggingScrollbar = true;
    _dragStartOffset = details.localPosition.dy;
    _dragStartScrollOffset = _controller.offset;
  }

  void _updateScrollbarDrag(DragUpdateDetails details) {
    if (!_controller.hasClients) return;
    if (!_isDraggingScrollbar) return;

    final position = _controller.position;
    final maxExtent = position.maxScrollExtent;
    final viewportHeight = position.viewportDimension;
    final (_, thumbHeight, _) = _getScrollbarGeometry();

    final scrollableHeight = viewportHeight - thumbHeight;
    if (scrollableHeight <= 0) return;

    final deltaY = details.localPosition.dy - _dragStartOffset;
    // reverse 模式：拖动方向需要反转
    final scrollDelta = widget.reverse
        ? -(deltaY / scrollableHeight) * maxExtent
        : (deltaY / scrollableHeight) * maxExtent;
    final newOffset = (_dragStartScrollOffset + scrollDelta).clamp(
      0.0,
      maxExtent,
    );

    _controller.jumpTo(newOffset);
    // 同步 futurePosition 使得拖动后鼠标滚轮继续从正确位置开始
    _futurePosition = newOffset;
  }

  void _endScrollbarDrag() {
    _isDraggingScrollbar = false;
  }

  Widget _buildScrollbar(Widget child) {
    if (!_isDesktopOrWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final (thumbTop, thumbHeight, visible) = _getScrollbarGeometry();

        if (!visible) return child;

        return Stack(
          children: [
            child,
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 20, // 增加点击热区
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {},
                onExit: (_) {},
                child: GestureDetector(
                  onVerticalDragStart: _startScrollbarDrag,
                  onVerticalDragUpdate: _updateScrollbarDrag,
                  onVerticalDragEnd: (_) => _endScrollbarDrag(),
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(top: thumbTop, right: 4),
                      width: widget.scrollbarWidth,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: Colors.transparent, // 始终透明
                        borderRadius: BorderRadius.circular(
                          widget.scrollbarWidth / 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 移动端：原生滚动
    if (!_isDesktopOrWeb) {
      return SingleChildScrollView(
        controller: _controller,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        padding: widget.padding,
        child: widget.child,
      );
    }

    // 桌面端/Web端：自定义平滑滚动 + 透明滚动条
    final scrollView = Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onPointerDown,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        physics: _physics,
        padding: widget.padding,
        child: widget.child,
      ),
    );

    return _buildScrollbar(scrollView);
  }
}

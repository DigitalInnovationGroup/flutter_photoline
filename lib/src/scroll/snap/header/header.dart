import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photoline/src/scroll/snap/header/controller.dart';
import 'package:photoline/src/scroll/snap/refresh/painter.dart';

class ScrollSnapHeader extends StatefulWidget {
  const ScrollSnapHeader({
    required this.header,
    required this.content,
    required this.controller,
    this.onRefresh,
    this.refreshTriggerExtent = 80.0,
    super.key,
  });

  final Widget header;
  final Widget content;
  final ScrollSnapHeaderController controller;

  /// If provided, enables pull-to-refresh when overscrolled past the
  /// fully-expanded header.
  final RefreshCallback? onRefresh;

  /// How far (in logical pixels) the user must pull past the expanded header
  /// to trigger a refresh.
  final double refreshTriggerExtent;

  @override
  State<ScrollSnapHeader> createState() => _ScrollSnapHeaderState();
}

class _ScrollSnapHeaderState extends State<ScrollSnapHeader>
    with TickerProviderStateMixin {
  Drag? _drag;

  // ── Refresh state ────────────────────────────────────────────────────────

  bool _armed = false;
  bool _refreshing = false;
  bool _pullingRefresh = false;
  bool _isSpinning = false;

  late final AnimationController _spinAnim;

  /// Collapse animation for dismissing the indicator after refresh or when
  /// released without arming.
  late final AnimationController _collapseAnim;

  /// Smoothly brings refreshPull down to [refreshTriggerExtent] after the
  /// user over-pulled before release (avoids the instant jump to triggerExtent).
  late final AnimationController _snapToTriggerAnim;
  double _snapToTriggerFrom = 0.0;

  @override
  void initState() {
    super.initState();
    final hc = widget.controller;
    hc.canRefresh = widget.onRefresh != null;
    hc.refreshTriggerExtent = widget.refreshTriggerExtent;
    hc.refreshPull.addListener(_onRefreshPullChanged);

    _spinAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _collapseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onCollapseTick);

    _snapToTriggerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onSnapToTriggerTick);
  }

  @override
  void didUpdateWidget(ScrollSnapHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.canRefresh = widget.onRefresh != null;
    widget.controller.refreshTriggerExtent = widget.refreshTriggerExtent;
  }

  @override
  void dispose() {
    widget.controller.refreshPull.removeListener(_onRefreshPullChanged);
    _collapseAnim.removeListener(_onCollapseTick);
    _collapseAnim.dispose();
    _snapToTriggerAnim.removeListener(_onSnapToTriggerTick);
    _snapToTriggerAnim.dispose();
    _spinAnim.dispose();
    super.dispose();
  }

  bool get _canRefresh => widget.onRefresh != null;

  double get _refreshPull => widget.controller.refreshPull.value;

  // ── Refresh pull listener (driven by scroll position) ────────────────────

  void _onRefreshPullChanged() {
    final pull = _refreshPull;
    final wasArmed = _armed;
    _armed = pull >= widget.refreshTriggerExtent;
    if (_armed && !wasArmed) {
      unawaited(HapticFeedback.mediumImpact());
      _startSpin((pull / widget.refreshTriggerExtent) % 1.0);
    } else if (!_armed && wasArmed && !_refreshing) {
      _stopSpin();
    }
    if (pull <= 0.0 && _collapseAnim.isAnimating) {
      _collapseAnim.stop();
    }
    if (pull <= 0.0 && _snapToTriggerAnim.isAnimating) {
      _snapToTriggerAnim.stop();
    }
    setState(() {});
  }

  void _startSpin(double fromFraction) {
    if (_isSpinning) return;
    _isSpinning = true;
    _spinAnim.value = fromFraction.clamp(0.0, 1.0);
    unawaited(_spinAnim.repeat());
  }

  void _stopSpin() {
    if (!_isSpinning) return;
    _isSpinning = false;
    _spinAnim.stop();
  }

  (double angle, double opacity) _spinnerValues() {
    final pull = _refreshPull;
    if (pull <= 0) return (0.0, 0.0);

    final trigger = widget.refreshTriggerExtent;

    if (_isSpinning) {
      return (_spinAnim.value * 2 * math.pi, (pull / trigger).clamp(0.0, 1.0));
    }

    const deadZone = 10.0;
    if (pull <= deadZone) return (0.0, 0.0);

    final fraction =
        ((pull - deadZone) / (trigger - deadZone)).clamp(0.0, 1.0);
    final angle = (pull / trigger % 1.0) * 2 * math.pi;
    return (angle, Curves.easeOut.transform(fraction));
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Whether the active scroll position is at (or past) its minimum extent
  /// AND the header is fully expanded.
  bool get _isAtTop {
    final hc = widget.controller;
    if (hc.height.value < hc.maxHeight - 0.5) return false;
    final sc = hc.activeScrollController;
    if (sc == null || !sc.hasClients) return true;
    final pos = sc.position;
    if (!pos.hasContentDimensions) return true;
    return pos.pixels <= pos.minScrollExtent + 0.5;
  }

  // ── Gesture handlers (for drags started on the header) ──────────────────

  void _onVerticalDragStart(DragStartDetails details) {
    if (_refreshing) return;
    _pullingRefresh = false;

    // Stop any in-progress collapse/snap animations so they don't compete
    // with the new gesture and leave refreshPull in a frozen state.
    if (_collapseAnim.isAnimating) _collapseAnim.stop();
    if (_snapToTriggerAnim.isAnimating) _snapToTriggerAnim.stop();

    final sc = widget.controller.activeScrollController;
    if (sc == null || !sc.hasClients) return;

    _drag = sc.position.drag(
      DragStartDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        sourceTimeStamp: details.sourceTimeStamp,
      ),
      () => _drag = null,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_refreshing) return;

    final double dy = details.primaryDelta ?? 0.0;

    // Pulling down (dy > 0) when header is fully expanded and at top.
    if (dy > 0 && _canRefresh && _isAtTop) {
      if (!_pullingRefresh) {
        _drag?.cancel();
        _drag = null;
        _pullingRefresh = true;
      }
    }

    if (_pullingRefresh) {
      // Feed the refresh pull directly through the header controller.
      final hc = widget.controller;
      final currentPull = hc.refreshPull.value;
      final double friction =
          (1.0 -
              (currentPull / (widget.refreshTriggerExtent * 3.0))
                  .clamp(0.0, 0.8));
      final double consumed = dy * friction;
      final double newPull =
          (currentPull + consumed).clamp(0.0, double.infinity);

      hc.refreshPull.value = newPull;

      if (newPull <= 0.0) {
        _pullingRefresh = false;
        hc.refreshPull.value = 0.0;
        _armed = false;
        final sc = hc.activeScrollController;
        if (sc != null && sc.hasClients) {
          _drag = sc.position.drag(
            DragStartDetails(globalPosition: details.globalPosition),
            () => _drag = null,
          );
        }
      }
      return;
    }

    _drag?.update(details);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_refreshing) return;

    if (_pullingRefresh) {
      _pullingRefresh = false;
      if (_canRefresh && _armed) {
        unawaited(_doRefresh());
      } else {
        _collapseIndicator();
      }
      return;
    }

    _drag?.end(details);
    _drag = null;
  }

  void _onVerticalDragCancel() {
    if (_pullingRefresh) {
      _pullingRefresh = false;
      if (!_refreshing) {
        _collapseIndicator();
      }
      return;
    }
    _drag?.cancel();
    _drag = null;
  }

  // ── Collapse animation ──────────────────────────────────────────────────

  double _collapseFrom = 0.0;

  void _collapseIndicator() {
    // Always stop any competing animation first.
    if (_snapToTriggerAnim.isAnimating) _snapToTriggerAnim.stop();
    _collapseFrom = widget.controller.refreshPull.value;
    if (_collapseFrom <= 0.0) {
      widget.controller.refreshPull.value = 0.0;
      _armed = false;
      setState(() {});
      return;
    }
    unawaited(_collapseAnim.forward(from: 0.0));
  }

  void _onCollapseTick() {
    // If the user grabbed and started pulling again, stop competing with them.
    if (_pullingRefresh) {
      _collapseAnim.stop();
      return;
    }
    final t = Curves.easeOut.transform(_collapseAnim.value);
    final computed = _collapseFrom * (1.0 - t);
    // Never let the collapse animation set a value *higher* than what's
    // already there — ballistic setPixels may have already reduced it further.
    final current = widget.controller.refreshPull.value;
    widget.controller.refreshPull.value = computed < current ? computed : current;
    _armed = false;
    if (_collapseAnim.isCompleted) {
      widget.controller.refreshPull.value = 0.0;
      setState(() {});
    }
  }

  // ── Refresh flow ─────────────────────────────────────────────────────────

  void _onSnapToTriggerTick() {
    final trigger = widget.refreshTriggerExtent;
    final t = Curves.easeOut.transform(_snapToTriggerAnim.value);
    // Interpolate from _snapToTriggerFrom → trigger as t goes 0 → 1.
    final value = _snapToTriggerFrom + (trigger - _snapToTriggerFrom) * t;
    widget.controller.refreshPull.value = value;
    if (_snapToTriggerAnim.isCompleted) {
      widget.controller.refreshPull.value = trigger;
    }
  }

  Future<void> _doRefresh() async {
    _refreshing = true;
    widget.controller.refreshing = true;

    // Smoothly bring refreshPull down to triggerExtent instead of jumping.
    final currentPull = widget.controller.refreshPull.value;
    final trigger = widget.refreshTriggerExtent;
    if (currentPull > trigger + 0.5) {
      _snapToTriggerFrom = currentPull;
      unawaited(_snapToTriggerAnim.forward(from: 0.0));
    } else if (currentPull != trigger) {
      widget.controller.refreshPull.value = trigger;
    }

    try {
      await widget.onRefresh!();
    } finally {
      if (mounted) {
        _stopSpin();
        _refreshing = false;
        widget.controller.refreshing = false;
        _armed = false;
        _collapseIndicator();
      }
    }
  }

  // ── Refresh indicator widget ─────────────────────────────────────────────

  Widget _buildRefreshIndicator() {
    final (angle, opacity) = _spinnerValues();
    return Center(
      child: SizedBox.square(
        dimension: 36,
        child: CustomPaint(
          painter: ScrollRefreshPainter(angle: angle, opacity: opacity),
        ),
      ),
    );
  }

  // ── Scroll notification handling ─────────────────────────────────────────

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_canRefresh || _refreshing) return false;

    if (notification is ScrollStartNotification) {
      // New scroll gesture started in content — stop any in-progress collapse
      // so they don't compete and freeze the indicator.
      if (_collapseAnim.isAnimating) _collapseAnim.stop();
      if (_snapToTriggerAnim.isAnimating) _snapToTriggerAnim.stop();
    }

    if (notification is ScrollEndNotification) {
      // User released the scroll. If we have accumulated refresh pull,
      // either trigger refresh or collapse.
      if (_refreshPull > 0 && !_pullingRefresh) {
        if (_armed && _canRefresh) {
          unawaited(_doRefresh());
        } else {
          // Always start collapse. The tick uses `computed < current` so it
          // never fights a ballistic drain — it just takes whichever value
          // is smaller, keeping the animation smooth in all cases.
          _collapseIndicator();
        }
      }
    }

    return false;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pull = _refreshPull;
    return ScrollSnapHeaderMultiChild(
      controller: widget.controller,
      refreshPull: pull,
      header: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onVerticalDragCancel: _onVerticalDragCancel,
        child: widget.header,
      ),
      refreshIndicator:
          _canRefresh && pull > 0 ? _buildRefreshIndicator() : null,
      content: _canRefresh
          ? NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: widget.content,
            )
          : widget.content,
    );
  }
}

// ==================================================================================================================

class ScrollSnapHeaderMultiChild extends MultiChildRenderObjectWidget {
  ScrollSnapHeaderMultiChild({
    super.key,
    required this.header,
    required this.content,
    required this.controller,
    this.refreshIndicator,
    this.refreshPull = 0.0,
  }) : super(children: [
          content,
          if (refreshIndicator != null) refreshIndicator,
          header,
        ]);

  final Widget header;
  final Widget content;
  final Widget? refreshIndicator;
  final ScrollSnapHeaderController controller;
  final double refreshPull;

  @override
  ScrollSnapScrollHeaderRenderBox createRenderObject(BuildContext context) =>
      ScrollSnapScrollHeaderRenderBox(
        controller: controller,
        refreshPull: refreshPull,
      );

  @override
  void updateRenderObject(
      BuildContext context, ScrollSnapScrollHeaderRenderBox renderObject) {
    renderObject.refreshPull = refreshPull;
  }
}

class ScrollSnapScrollHeaderRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  ScrollSnapScrollHeaderRenderBox({
    required this.controller,
    double refreshPull = 0.0,
  }) : _refreshPull = refreshPull;

  @override
  void attach(PipelineOwner owner) {
    controller.height.addListener(markNeedsLayout);
    super.attach(owner);
  }

  @override
  void detach() {
    controller.height.removeListener(markNeedsLayout);
    super.detach();
  }

  ScrollSnapHeaderController controller;

  double get refreshPull => _refreshPull;
  double _refreshPull;

  set refreshPull(double value) {
    if (value == _refreshPull) return;
    _refreshPull = value;
    markNeedsLayout();
  }

  /// Children order: [content, (refreshIndicator)?, header]
  /// firstChild = content, lastChild = header
  RenderBox get _headerBox => lastChild!;

  RenderBox get _contentBox => firstChild!;

  /// The optional refresh indicator is between content and header.
  RenderBox? get _refreshBox {
    final next =
        (_contentBox.parentData! as MultiChildLayoutParentData).nextSibling;
    return next == _headerBox ? null : next;
  }

  @override
  void performLayout() {
    final c = constraints.loosen();

    // Layout header at its natural height (no stretching for refresh).
    _headerBox.layout(
      c.copyWith(maxHeight: controller.height.value),
      parentUsesSize: true,
    );

    // Layout the optional refresh indicator if present.
    final refreshBox = _refreshBox;
    if (refreshBox != null) {
      refreshBox.layout(
        c.copyWith(
          minHeight: _refreshPull,
          maxHeight: _refreshPull,
        ),
        parentUsesSize: true,
      );
    }

    _contentBox.layout(c, parentUsesSize: true);

    final width = c.constrainWidth(
      math.max(c.minWidth, _contentBox.size.width),
    );
    final height = c.constrainHeight(
      math.max(c.minHeight, _contentBox.size.height),
    );
    size = Size(width, height);

    // Content is pushed down by the refresh pull amount.
    (_contentBox.parentData! as MultiChildLayoutParentData).offset =
        Offset(0, _refreshPull);

    // Header is on top.
    (_headerBox.parentData! as MultiChildLayoutParentData).offset =
        Offset.zero;

    // Refresh indicator sits right below the header.
    if (refreshBox != null) {
      (refreshBox.parentData! as MultiChildLayoutParentData).offset =
          Offset(0, _headerBox.size.height);
    }
  }

  @override
  void setupParentData(RenderObject child) {
    super.setupParentData(child);
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _contentBox.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _contentBox.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _contentBox.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _contentBox.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result as BoxHitTestResult, position: position);

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

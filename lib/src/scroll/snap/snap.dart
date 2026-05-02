import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photoline/library.dart';
import 'package:photoline/src/mixin/state/rebuild.dart';
import 'package:photoline/src/scroll/snap/snap/physics.dart';
import 'package:photoline/src/scroll/snap/snap/viewport/viewport.dart';

export 'snap/sliver/list.dart';

typedef ScrollSnapRebuilder = List<Widget> Function(VoidCallback fn);

class ScrollSnap extends StatefulWidget {
  const ScrollSnap({
    super.key,
    required this.controller,
    this.slivers,
    this.builder,
    this.cacheExtent = double.infinity,
  });

  final ScrollSnapRebuilder? builder;
  final List<Widget>? slivers;
  final ScrollSnapController controller;
  final double cacheExtent;

  @override
  State<ScrollSnap> createState() => ScrollSnapState();
}

class ScrollSnapState extends State<ScrollSnap>
    with StateRebuildMixin, WidgetsBindingObserver, TickerProviderStateMixin {
  ScrollPhysics? _physics;

  ScrollSnapController get controller => widget.controller;

  Timer? _timer;

  // --- Refresh ---
  bool get _hasRefresh => controller.onReload != null;

  bool _isRefreshing = false;
  bool _isClosing = false;
  bool _isSpinning = false;
  bool _hasTrigger = false;

  late final AnimationController _spinController;
  late final AnimationController _closeController;
  late final AnimationController _snapToTriggerController;
  double _snapToTriggerFrom = 0.0;

  double get _spinAngle => _spinController.value * 2 * math.pi;

  void _startSpin(double fromFraction) {
    if (_isSpinning) return;
    _isSpinning = true;
    _spinController.value = fromFraction.clamp(0.0, 1.0);
    unawaited(_spinController.repeat());
  }

  void _stopSpin() {
    if (!_isSpinning) return;
    _isSpinning = false;
    _spinController.stop();
  }

  // Called when controller.refreshPull changes (written by scroll position physics)
  void _onRefreshPullChanged() {
    if (!_isRefreshing && !_isClosing) {
      final pull = controller.refreshPull.value;
      final crossed = pull >= controller.refreshTriggerExtent;
      if (crossed && !_hasTrigger) {
        _hasTrigger = true;
        unawaited(HapticFeedback.mediumImpact());
        _startSpin((pull / controller.refreshTriggerExtent) % 1.0);
      } else if (!crossed && _hasTrigger) {
        _hasTrigger = false;
        _stopSpin();
      }
    }
    rebuild();
  }

  // The pull value from which the current collapse animation started.
  double _collapseFrom = 0.0;

  void _onCloseTick() {
    if (!_isClosing) return;
    final t = Curves.easeOut.transform(_closeController.value);
    controller.refreshPull.value = _collapseFrom * (1.0 - t);
  }

  void _onCloseStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed || !_isClosing) return;
    _stopSpin();
    _isClosing = false;
    controller.refreshing = false;
    controller.refreshPull.value = 0.0;
    _hasTrigger = false;
  }

  void _onSnapToTriggerTick() {
    final trigger = controller.refreshTriggerExtent;
    final t = Curves.easeOut.transform(_snapToTriggerController.value);
    controller.refreshPull.value =
        _snapToTriggerFrom + (trigger - _snapToTriggerFrom) * t;
  }

  // Animates refreshPull from its current value back to 0.
  void _startCollapse() {
    if (_isClosing || controller.refreshPull.value <= 0) return;
    if (_snapToTriggerController.isAnimating) _snapToTriggerController.stop();
    _collapseFrom = controller.refreshPull.value;
    _isClosing = true;
    unawaited(_closeController.forward(from: 0.0));
    rebuild();
  }

  Future<void> _checkRefreshTrigger() async {
    if (!_hasRefresh || _isRefreshing || _isClosing || !_hasTrigger) return;
    _isRefreshing = true;
    controller.refreshing = true;

    final currentPull = controller.refreshPull.value;
    final trigger = controller.refreshTriggerExtent;
    if (currentPull > trigger + 0.5) {
      _snapToTriggerFrom = currentPull;
      unawaited(_snapToTriggerController.forward(from: 0.0));
    } else {
      controller.refreshPull.value = trigger;
    }

    rebuild();

    await controller.onReload!();
    if (!mounted) return;

    _isRefreshing = false;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    _startCollapse();
  }

  Future<void> _onDragChange() async {
    if (controller.isUserDrag.value) return;
    await _checkRefreshTrigger();
    // If refresh didn't trigger, collapse the partial pull back to zero.
    _startCollapse();
  }

  (double angle, double opacity) _spinnerValues() {
    final pull = controller.refreshPull.value;
    if (pull <= 0) return (0.0, 0.0);

    final trigger = controller.refreshTriggerExtent;

    if (_isSpinning) {
      return (_spinAngle, (pull / trigger).clamp(0.0, 1.0));
    }

    const deadZone = 10.0;
    if (pull <= deadZone) return (0.0, 0.0);

    final fraction = ((pull - deadZone) / (trigger - deadZone)).clamp(0.0, 1.0);
    final angle = (pull / trigger % 1.0) * 2 * math.pi;
    return (angle, Curves.easeOut.transform(fraction));
  }

  // --- Keyboard handling ---

  @override
  void didChangeMetrics() {
    final media = MediaQuery.of(context);
    if (!mounted) return;
    final wbox = context.findRenderObject();
    if (wbox is! RenderBox || !wbox.hasSize) return;
    final wdy = wbox.localToGlobal(Offset.zero).dy;
    final wh = wbox.size.height;
    final h = media.size.height;
    final vib = media.viewInsets.bottom;
    const double gap = 20;
    final double kov = math.max(0, vib - h + wdy + wh);
    if (!kov.isNaN) controller.keyboardOverlap = kov;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1), () async {
      if (!mounted) return;
      final FocusNode? activeNode = FocusManager.instance.primaryFocus;
      if (activeNode?.context == null) return;
      final fco = activeNode!.context!;
      if (fco.findAncestorStateOfType<ScrollSnapState>() != this) return;
      final fro = fco.findRenderObject();
      if (fro is! RenderBox || !fro.hasSize) return;
      final fdy = fro.localToGlobal(Offset.zero).dy;
      final fh = fro.size.height;
      final foverlap = math.max(0, vib - h + fdy + fh + gap);
      if (foverlap <= 0) return;
      await controller.position.animateTo(
        controller.position.pixels + foverlap,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(rebuild);
    _closeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_onCloseTick)
     ..addStatusListener(_onCloseStatus);
    _snapToTriggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onSnapToTriggerTick);
    if (_hasRefresh) {
      controller.refreshPull.addListener(_onRefreshPullChanged);
      controller.isUserDrag.addListener(_onDragChange);
    }
  }

  @override
  void dispose() {
    if (_hasRefresh) {
      controller.refreshPull.removeListener(_onRefreshPullChanged);
      controller.isUserDrag.removeListener(_onDragChange);
    }
    _spinController.dispose();
    _closeController.dispose();
    _snapToTriggerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          controller.boxConstraints = constraints;
          _physics ??= ScrollSnapPhysics(controller: controller);

          final scrollable = NotificationListener(
            onNotification: (notification) {
              if (notification is PhotolinePointerScrollNotification) {
                final dx = notification.event.scrollDelta.dy;
                final double velocity = (math.max(dx.abs(), 50) * dx.sign) * 10;
                controller.position.goBallistic(velocity);
                return false;
              }
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                controller.isUserDrag.value = true;
              }
              if (notification is ScrollUpdateNotification) {
                controller.isUserDrag.value = notification.dragDetails != null;
              }
              if (notification is ScrollEndNotification) {
                controller.isUserDrag.value = false;
              }
              return false;
            },
            child: PhotolineScrollable(
              controller: controller,
              physics: _physics,
              viewportBuilder: (context, position) => ScrollSnapViewport(
                cacheExtent: widget.cacheExtent,
                offset: position,
                children: widget.builder?.call(rebuild) ?? widget.slivers ?? [],
              ),
            ),
          );

          if (!_hasRefresh) return scrollable;

          final pull = controller.refreshPull.value;
          final (angle, opacity) = _spinnerValues();

          return ScrollRefreshLayout(
            refreshPull: pull,
            indicator: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox.square(
                  dimension: 36,
                  child: CustomPaint(
                    painter: ScrollRefreshPainter(angle: angle, opacity: opacity),
                  ),
                ),
              ),
            ),
            scrollable: scrollable,
          );
        },
      );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photoline/src/mixin/state/rebuild.dart';
import 'package:photoline/src/scroll/snap/controller.dart';
import 'package:photoline/src/scroll/snap/refresh/sliver.dart';

class ScrollSnapRefresh extends StatefulWidget {
  const ScrollSnapRefresh({super.key, required this.controller});

  final ScrollSnapController controller;

  @override
  State<ScrollSnapRefresh> createState() => ScrollSnapRefreshState();
}

class ScrollSnapRefreshState extends State<ScrollSnapRefresh>
    with StateRebuildMixin, TickerProviderStateMixin {
  int viewState = 0;
  bool isWait = false;
  bool isWaitClose = false;
  bool isClosing = false;

  ScrollSnapController get _controller => widget.controller;

  // Drives sliver height during close animation (1.0 → 0.0)
  late final AnimationController animationController;

  // Drives continuous rotation (repeats 0.0 → 1.0)
  late final AnimationController _spinController;

  bool _isSpinning = false;

  double get _currentAngle => _spinController.value * 2 * math.pi;

  final double _triggerExtent = 60;

  double get overlapHeight => switch (viewState) {
        0 => animationController.value * _triggerExtent,
        1 || 2 => _triggerExtent,
        _ => 0,
      };

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

  Future<void> _handleScroll() async {
    if (_controller.isUserDrag.value || isWait || viewState != 1 || isWaitClose) return;

    isWait = true;
    isWaitClose = true;
    viewState = 2;
    animationController
      ..stop()
      ..value = 1;
    rebuild();

    await widget.controller.onRefresh?.call();

    if (!mounted) return;
    viewState = 0;
    isWait = false;
    isClosing = true;
    animationController.stop();

    void onAnimationDone(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animationController.removeStatusListener(onAnimationDone);
      _stopSpin();
      isClosing = false;
      isWaitClose = false;

      if (widget.controller.hasClients) {
        final pos = widget.controller.position;
        final minExtent = pos.minScrollExtent;
        if (pos.pixels < minExtent) pos.forcePixels(minExtent);
      }
    }

    animationController.addStatusListener(onAnimationDone);
    unawaited(animationController.reverse(from: animationController.value));
    rebuild();
  }

  int _setView(double height) => height > _triggerExtent ? 1 : 0;

  @override
  void initState() {
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(rebuild);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(rebuild);

    super.initState();
    _controller.isUserDrag.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.isUserDrag.removeListener(_handleScroll);
    animationController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollSnapRefreshSliver(
        refresh: this,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;

            if (h == 0) {
              if (!isWait && isWaitClose) isWaitClose = false;
              return const SizedBox();
            }

            final v = _setView(h);

            if (!isWait && !isWaitClose) {
              if (viewState != v) {
                if (v == 1) {
                  unawaited(HapticFeedback.mediumImpact());
                  // Start spin from where the pull rotation left off
                  _startSpin((h / _triggerExtent) % 1.0);
                } else if (_isSpinning) {
                  _stopSpin();
                }
                viewState = v;
              }
            }

            final double angle;
            final double opacity;

            if (isClosing || isWaitClose) {
              angle = _currentAngle;
              opacity = animationController.value;
            } else if (_isSpinning) {
              angle = _currentAngle;
              opacity = 1.0;
            } else {
              final fraction = (h / _triggerExtent).clamp(0.0, 1.0);
              angle = fraction * 2 * math.pi;
              opacity = fraction;
            }

            return Center(
              child: SizedBox.square(
                dimension: 36,
                child: CustomPaint(
                  painter: _PetalsPainter(angle: angle, opacity: opacity),
                ),
              ),
            );
          },
        ),
      );
}

class _PetalsPainter extends CustomPainter {
  const _PetalsPainter({required this.angle, required this.opacity});

  final double angle;
  final double opacity;

  static const int _count = 12;
  static const double _falloff = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final innerR = r * 0.32;
    final outerR = r * 0.78;
    final strokeW = r * 0.18;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _count; i++) {
      final petalAngle = (i / _count) * 2 * math.pi - math.pi / 2;
      final diff = (angle - petalAngle + math.pi * 2) % (math.pi * 2);
      final stepsBehind = diff / (2 * math.pi / _count);
      final petalOpacity = math.pow(_falloff, stepsBehind).toDouble() * opacity;

      paint.color = Color.fromRGBO(172, 172, 172, petalOpacity);

      final from = center + Offset(math.cos(petalAngle) * innerR, math.sin(petalAngle) * innerR);
      final to = center + Offset(math.cos(petalAngle) * outerR, math.sin(petalAngle) * outerR);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_PetalsPainter old) => old.angle != angle || old.opacity != opacity;
}

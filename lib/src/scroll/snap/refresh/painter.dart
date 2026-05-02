import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class ScrollRefreshPainter extends CustomPainter {
  const ScrollRefreshPainter({required this.angle, required this.opacity});

  final double angle;
  final double opacity;

  static const int _count = 12;
  static const double _falloff = 0.78;

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
      final petalOpacity = (math.pow(_falloff, stepsBehind).toDouble() * opacity).clamp(0.0, 1.0);
      paint.color = Color.fromRGBO(172, 172, 172, petalOpacity);
      final from = center + Offset(math.cos(petalAngle) * innerR, math.sin(petalAngle) * innerR);
      final to = center + Offset(math.cos(petalAngle) * outerR, math.sin(petalAngle) * outerR);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(ScrollRefreshPainter old) => old.angle != angle || old.opacity != opacity;
}

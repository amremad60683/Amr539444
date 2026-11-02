import 'dart:math';

import 'package:flutter/material.dart';

/// Circular progress ring with a marker for the daily target.
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.progress,
    required this.targetFraction,
    required this.color,
    required this.child,
    this.size = 150,
  });

  /// spent / allowance (may exceed 1).
  final double progress;

  /// target / allowance, drawn as a small tick.
  final double targetFraction;
  final Color color;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(value, targetFraction.clamp(0, 1).toDouble(), color, track,
              Theme.of(context).colorScheme.onSurfaceVariant),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.target, this.color, this.track, this.tick);
  final double progress;
  final double target;
  final Color color;
  final Color track;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, bg);
    if (progress > 0) canvas.drawArc(r, -pi / 2, 2 * pi * progress, false, fg);

    if (target > 0 && target < 1) {
      final a = -pi / 2 + 2 * pi * target;
      final c = size.center(Offset.zero);
      final rad = size.width / 2;
      final p1 = c + Offset(cos(a), sin(a)) * (rad - stroke - 2);
      final p2 = c + Offset(cos(a), sin(a)) * (rad + 1);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = tick
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.target != target;
}

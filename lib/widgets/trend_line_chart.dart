import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/workout_format.dart';

/// Simple line chart for weights. [values] are in kg, oldest first; the
/// axis labels are shown in the unit currently selected in Settings.
class TrendLineChart extends StatelessWidget {
  final List<double> values;
  final double height;

  const TrendLineChart({super.key, required this.values, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendLinePainter(values: values, colors: context.colors),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final AppPalette colors;

  const _TrendLinePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final flat = maxValue == minValue;
    final span = flat ? 1.0 : maxValue - minValue;

    const top = 20.0;
    const bottom = 8.0;
    const side = 10.0;
    final chartWidth = size.width - side * 2;
    final chartHeight = size.height - top - bottom;

    // Grid lines (top = max, middle, bottom = min).
    final gridPaint = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Axis labels.
    void label(String text, double y) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: colors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(0, y - painter.height - 2));
    }

    label(formatWeight(maxValue), top);
    if (!flat) label(formatWeight(minValue), top + chartHeight);

    Offset pointAt(int i) {
      final x = side + chartWidth * i / (values.length - 1);
      final y = flat
          ? top + chartHeight / 2
          : top + chartHeight * (1 - (values[i] - minValue) / span);
      return Offset(x, y);
    }

    // Line.
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = colors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dots (skipped when there are many points).
    if (values.length <= 40) {
      final dotPaint = Paint()..color = colors.ink;
      for (var i = 0; i < values.length - 1; i++) {
        canvas.drawCircle(pointAt(i), 3.5, dotPaint);
      }
    }

    // Latest point highlighted.
    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 7, Paint()..color = AppColors.accent);
    canvas.drawCircle(
      last,
      7,
      Paint()
        ..color = colors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
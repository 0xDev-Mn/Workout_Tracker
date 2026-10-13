import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/progress_stats.dart';
import '../utils/workout_format.dart';

class ExerciseProgressScreen extends StatelessWidget {
  final ExerciseRecord record;

  const ExerciseProgressScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sessions = record.sessions;
    final newestFirst = sessions.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          record.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (record.muscleGroup.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(record.muscleGroup, style: t.bodySmall),
            ),
          _buildSummary(context),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top set weight', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text('Heaviest set each workout (kg)', style: t.bodySmall),
                  const SizedBox(height: 16),
                  if (sessions.length < 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Log this exercise again to see a trend.',
                          style: t.bodySmall?.copyWith(fontSize: 14),
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 180,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _LineChartPainter(
                          values: sessions.map((s) => s.topWeight).toList(),
                          colors: context.colors,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatShortDate(sessions.first.date),
                          style: t.bodySmall,
                        ),
                        Text(
                          formatShortDate(sessions.last.date),
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('History', style: t.titleMedium),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < newestFirst.length; i++)
                  _SessionRow(
                    session: newestFirst[i],
                    showDivider: i < newestFirst.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    Widget divider() =>
        Container(width: 1, height: 32, color: context.colors.border);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          stat(
            '${formatWeight(record.bestWeight)} × ${record.bestWeightReps}',
            'Best set (kg)',
          ),
          divider(),
          stat('${record.bestOneRm.round()} kg', 'Est. 1RM'),
          divider(),
          stat('${record.sessions.length}', 'Sessions'),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionPoint session;
  final bool showDivider;

  const _SessionRow({required this.session, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: context.colors.border))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatLongDate(session.date),
              style: t.bodyMedium,
            ),
          ),
          Text(
            '${formatWeight(session.topWeight)} kg × ${session.topWeightReps}',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final AppPalette colors;

  const _LineChartPainter({required this.values, required this.colors});

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

    // Dots.
    final dotPaint = Paint()..color = colors.ink;
    for (var i = 0; i < values.length - 1; i++) {
      canvas.drawCircle(pointAt(i), 3.5, dotPaint);
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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
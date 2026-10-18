import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/progress_stats.dart';
import '../utils/workout_format.dart';
import '../widgets/trend_line_chart.dart';

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
                  Text('Heaviest set each workout ($unitLabel)', style: t.bodySmall),
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
                    TrendLineChart(
                      values: sessions.map((s) => s.topWeight).toList(),
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
            'Best set ($unitLabel)',
          ),
          divider(),
          stat('${formatWeightRounded(record.bestOneRm)} $unitLabel', 'Est. 1RM'),
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
            '${formatWeight(session.topWeight)} $unitLabel × ${session.topWeightReps}',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
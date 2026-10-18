import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/body_weight_entry.dart';
import '../services/body_weight_storage.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/progress_stats.dart';
import '../utils/workout_format.dart';
import '../widgets/body_weight_sheet.dart';
import '../widgets/trend_line_chart.dart';
import 'body_weight_screen.dart';
import 'exercise_progress_screen.dart';

enum _MusclePeriod { week, month, all }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressStats? _stats;
  List<BodyWeightEntry> _bodyWeights = []; // oldest first
  bool _loading = true;

  // Period shown in the muscle-group card.
  _MusclePeriod _musclePeriod = _MusclePeriod.week;

  // Search inside "Personal records".
  bool _searching = false;

  // Personal records: only the most recent few are listed until expanded.
  static const int _recordPreviewCount = 5;
  bool _showAllRecords = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    // Reload automatically when a workout is finished or deleted.
    WorkoutEvents.changes.addListener(_load);
  }

  @override
  void dispose() {
    WorkoutEvents.changes.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> _load() async {
    final workouts = await WorkoutStorage.getWorkouts();
    final bodyWeights = await BodyWeightStorage.getEntries();
    if (!mounted) return;

    setState(() {
      _stats = ProgressStats.from(workouts);
      _bodyWeights = bodyWeights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stats = _stats;

    return Scaffold(
      body: SafeArea(
        child: _loading || stats == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text('Your training', style: t.bodySmall),
                  const SizedBox(height: 2),
                  Text('Progress', style: t.headlineMedium),
                  const SizedBox(height: 24),
                  if (stats.totalWorkouts == 0)
                    _buildEmpty(context)
                  else ...[
                    _buildSummary(context, stats),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Workouts per week',
                      subtitle: 'Last ${stats.weeks.length} weeks',
                      child: _WeeklyBars(
                        values:
                            stats.weeks.map((w) => w.workouts.toDouble()).toList(),
                        labels:
                            stats.weeks.map((w) => formatShortDate(w.start)).toList(),
                        format: (v) => v.round().toString(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: 'Weekly volume',
                      subtitle: 'Total weight lifted ($unitLabel)',
                      child: _WeeklyBars(
                        values: stats.weeks.map((w) => w.volume).toList(),
                        labels:
                            stats.weeks.map((w) => formatShortDate(w.start)).toList(),
                        format: formatCompactVolume,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMuscleCard(context, stats),
                    const SizedBox(height: 12),
                    _BodyWeightCard(
                      entries: _bodyWeights,
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BodyWeightScreen(),
                        ),
                      ),
                      onLog: () => showBodyWeightSheet(context),
                    ),
                    const SizedBox(height: 28),
                    _buildRecords(context, stats),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.bar_chart, size: 44, color: AppColors.accent),
          const SizedBox(height: 16),
          Text('Your progress starts here', style: t.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Finish your first workout to see your consistency, '
            'volume and personal records.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, ProgressStats stats) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
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
          stat('${stats.totalWorkouts}', 'Workouts'),
          divider(),
          stat(formatVolume(stats.totalVolume), 'Total volume'),
          divider(),
          stat(stats.avgPerWeek.toStringAsFixed(1), 'Avg / week'),
        ],
      ),
    );
  }

  DateTime? get _muscleSince {
    final now = DateTime.now();

    switch (_musclePeriod) {
      case _MusclePeriod.week:
        return weekStartOf(now);
      case _MusclePeriod.month:
        return DateTime(now.year, now.month, now.day - 29);
      case _MusclePeriod.all:
        return null;
    }
  }

  Widget _buildMuscleCard(BuildContext context, ProgressStats stats) {
    final t = Theme.of(context).textTheme;
    final counts = stats.setsByMuscle(since: _muscleSince);

    final groups = kMuscleGroups
        .where((g) => g != 'Other' || (counts['Other'] ?? 0) > 0)
        .toList();
    final maxSets = groups.fold<int>(0, (m, g) => math.max(m, counts[g] ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Muscle groups', style: t.titleMedium),
            const SizedBox(height: 2),
            Text('Sets per muscle group', style: t.bodySmall),
            const SizedBox(height: 14),
            _PeriodChips(
              selected: _musclePeriod,
              onChanged: (p) => setState(() => _musclePeriod = p),
            ),
            const SizedBox(height: 14),
            if (maxSets == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No sets logged in this period.',
                  style: t.bodySmall?.copyWith(fontSize: 14),
                ),
              )
            else
              for (final group in groups)
                _MuscleRow(
                  label: group,
                  sets: counts[group] ?? 0,
                  maxSets: maxSets,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecords(BuildContext context, ProgressStats stats) {
    final t = Theme.of(context).textTheme;

    final query = _query.trim().toLowerCase();
    final records = query.isEmpty
        ? stats.records
        : stats.records
            .where((r) => r.name.toLowerCase().contains(query))
            .toList();

    final canCollapse =
        query.isEmpty && records.length > _recordPreviewCount;
    final shown = (canCollapse && !_showAllRecords)
        ? records.take(_recordPreviewCount).toList()
        : records;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Personal records', style: t.titleMedium),
              ),
            ),
            if (stats.records.isNotEmpty)
              IconButton(
                tooltip: _searching ? 'Close search' : 'Search exercises',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _searching ? Icons.close : Icons.search,
                  color: context.colors.muted,
                ),
                onPressed: _toggleSearch,
              ),
          ],
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search exercises',
                hintStyle: TextStyle(color: context.colors.muted),
                prefixIcon: Icon(Icons.search, color: context.colors.muted),
                filled: true,
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.ink, width: 1.2),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Tap an exercise to see its trend', style: t.bodySmall),
          ),
        if (stats.records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              'Log weight and reps to see your records here.',
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
          )
        else if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              'No records match "$_query"',
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _RecordRow(
                    record: shown[i],
                    showDivider: i < shown.length - 1,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseProgressScreen(
                          record: shown[i],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (records.isNotEmpty && canCollapse)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllRecords = !_showAllRecords),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.muted,
                ),
                child: Text(
                  _showAllRecords
                      ? 'Show less'
                      : 'Show all (${records.length})',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: t.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart: one bar per week, the last one (this week) highlighted.
class _WeeklyBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String Function(double) format;

  const _WeeklyBars({
    required this.values,
    required this.labels,
    required this.format,
  });

  static const double _barArea = 96;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);

    return SizedBox(
      height: _barArea + 14 + 4 + 8 + 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final value = values[i];
          final isCurrent = i == values.length - 1;
          final barHeight =
              maxValue == 0 ? 4.0 : math.max(4.0, _barArea * value / maxValue);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 14,
                  child: value > 0
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            format(value),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.colors.ink,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: value == 0
                          ? context.colors.border
                          : isCurrent
                              ? AppColors.accent
                              : context.colors.barPast,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? context.colors.ink : context.colors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final ExerciseRecord record;
  final bool showDivider;
  final VoidCallback onTap;

  const _RecordRow({
    required this.record,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: context.colors.border))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Best ${formatWeight(record.bestWeight)} $unitLabel × '
                    '${record.bestWeightReps}',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatWeightRounded(record.bestOneRm)} $unitLabel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.ink,
                  ),
                ),
                Text('est. 1RM', style: t.bodySmall),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: context.colors.muted),
          ],
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final _MusclePeriod selected;
  final ValueChanged<_MusclePeriod> onChanged;

  const _PeriodChips({required this.selected, required this.onChanged});

  String _label(_MusclePeriod p) {
    switch (p) {
      case _MusclePeriod.week:
        return 'This week';
      case _MusclePeriod.month:
        return '30 days';
      case _MusclePeriod.all:
        return 'All time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final period in _MusclePeriod.values)
          ChoiceChip(
            label: Text(_label(period)),
            selected: selected == period,
            showCheckmark: false,
            onSelected: (_) => onChanged(period),
            selectedColor: AppColors.accent,
            backgroundColor: context.colors.bg,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected == period
                    ? AppColors.accent
                    : context.colors.border,
              ),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected == period
                  ? AppColors.onAccent
                  : context.colors.ink,
            ),
          ),
      ],
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final String label;
  final int sets;
  final int maxSets;

  const _MuscleRow({
    required this.label,
    required this.sets,
    required this.maxSets,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: t.bodyMedium)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: maxSets == 0 ? 0 : sets / maxSets,
                minHeight: 10,
                backgroundColor: context.colors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$sets',
              textAlign: TextAlign.right,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightCard extends StatelessWidget {
  final List<BodyWeightEntry> entries; // oldest first
  final VoidCallback onOpen;
  final VoidCallback onLog;

  const _BodyWeightCard({
    required this.entries,
    required this.onOpen,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final latest = entries.isEmpty ? null : entries.last;

    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day - 89);
    final recent = entries.where((e) => !e.date.isBefore(since)).toList();
    final change =
        latest != null && recent.length >= 2 ? latest.kg - recent.first.kg : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: latest == null ? onLog : onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Body weight', style: t.titleMedium)),
                  IconButton(
                    tooltip: 'Log weight',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.add_rounded,
                      color: context.colors.muted,
                    ),
                    onPressed: onLog,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: latest == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Track your weight over time.',
                            style: t.bodySmall?.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onLog,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Log weight'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${formatWeight(latest.kg)} $unitLabel',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.ink,
                                ),
                              ),
                              if (change != null) ...[
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${change >= 0 ? '+' : '−'}'
                                    '${formatWeight(change.abs())} '
                                    '$unitLabel · 90 days',
                                    style: t.bodySmall,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (recent.length >= 2) ...[
                            const SizedBox(height: 8),
                            TrendLineChart(
                              values: recent.map((e) => e.kg).toList(),
                              height: 110,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
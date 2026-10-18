import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/workout.dart';
import '../models/workout_ex.dart';
import '../models/workout_set.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/pr_utils.dart';
import '../utils/workout_format.dart';
import 'template_actions.dart';

/// Shown right after a workout is finished.
class WorkoutSummaryScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutSummaryScreen({super.key, required this.workout});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  List<PersonalRecord> _records = [];

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    // Best weights from every workout except this one.
    final previous = await WorkoutStorage.getBestWeights(
      excludeWorkoutId: widget.workout.id,
    );
    if (!mounted) return;

    final records = findRecords(widget.workout, previous);
    setState(() => _records = records);

    if (records.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 250));
      HapticFeedback.heavyImpact();
    }
  }

  List<WorkoutSet> _countedSets(WorkoutExercise e) => e.sets
      .where(
        (s) =>
            s.isDone &&
            !s.isWarmup &&
            (s.weight != null || s.reps != null),
      )
      .toList();

  /// "best 80 kg × 8" (or "best 12 reps" for bodyweight exercises)
  String _bestSet(List<WorkoutSet> sets) {
    WorkoutSet? best;
    for (final s in sets) {
      if (best == null ||
          (s.weight ?? 0) > (best.weight ?? 0) ||
          ((s.weight ?? 0) == (best.weight ?? 0) &&
              (s.reps ?? 0) > (best.reps ?? 0))) {
        best = s;
      }
    }

    if (best == null) return '';
    if ((best.weight ?? 0) > 0) {
      return 'best ${formatWeight(best.weight)} $unitLabel × ${best.reps ?? 0}';
    }
    return 'best ${best.reps ?? 0} reps';
  }

  double _exerciseVolume(List<WorkoutSet> sets) =>
      sets.fold(0.0, (sum, s) => sum + (s.weight ?? 0) * (s.reps ?? 0));

  @override
  Widget build(BuildContext context) {
    final w = widget.workout;
    final t = Theme.of(context).textTheme;
    final duration = workoutDuration(w);
    final exercises = doneExercises(w);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Workout complete',
              textAlign: TextAlign.center,
              style: t.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasName(w) ? w.name!.trim() : formatLongDate(w.date),
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 28),
            _StatsRow(
              duration: duration == null ? '—' : formatDuration(duration),
              volume: formatVolume(workoutVolume(w)),
              sets: '${workoutSetCount(w)}',
            ),
            const SizedBox(height: 28),
            if (_records.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('New personal records', style: t.titleMedium),
              ),
              _RecordsCard(records: _records),
              const SizedBox(height: 28),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Exercises', style: t.titleMedium),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < exercises.length; i++)
                    _ExerciseRow(
                      name: exercises[i].exercise.name,
                      detail: () {
                        final sets = _countedSets(exercises[i]);
                        return '${sets.length} '
                            '${sets.length == 1 ? 'set' : 'sets'}'
                            ' · ${_bestSet(sets)}';
                      }(),
                      volume: _exerciseVolume(_countedSets(exercises[i])),
                      showDivider: i < exercises.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => saveWorkoutAsTemplate(context, w),
                icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                label: const Text('Save as template'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String duration;
  final String volume;
  final String sets;

  const _StatsRow({
    required this.duration,
    required this.volume,
    required this.sets,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          stat(duration, 'Time'),
          divider(),
          stat(volume, 'Volume'),
          divider(),
          stat(sets, 'Sets'),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final String name;
  final String detail;
  final double volume;
  final bool showDivider;

  const _ExerciseRow({
    required this.name,
    required this.detail,
    required this.volume,
    required this.showDivider,
  });

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(detail, style: t.bodySmall?.copyWith(fontSize: 14)),
              ],
            ),
          ),
          if (volume > 0) ...[
            const SizedBox(width: 12),
            Text(
              formatVolume(volume),
              style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  final List<PersonalRecord> records;

  const _RecordsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(120)),
      ),
      child: Column(
        children: [
          for (final record in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 20,
                      color: AppColors.onAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.exerciseName, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Previous best ${formatWeight(record.previousBest)} $unitLabel',
                          style: t.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatWeight(record.weight)} $unitLabel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${formatWeight(record.increase)} $unitLabel',
                        style: t.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
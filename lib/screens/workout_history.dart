import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import 'rename_workout_dialog.dart';
import 'workout_actions.dart';
import 'workout_details.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  final List<Workout> workouts;

  const WorkoutHistoryScreen({
    super.key,
    required this.workouts,
  });

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late List<Workout> workouts;

  @override
  void initState() {
    super.initState();
    workouts = List.from(widget.workouts);
  }

  Future<void> confirmDelete(
    BuildContext context,
    Workout workout,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete workout?'),
        content: const Text(
          'This workout will be removed from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: context.colors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await WorkoutStorage.deleteWorkout(workout);
    WorkoutEvents.notifyChanged();

    if (!mounted) return;

    setState(() {
      workouts.remove(workout);
    });
  }

  Future<void> _openDetails(Workout workout) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailsScreen(workout: workout),
      ),
    );

    // If it was deleted on the details screen it is already gone from
    // storage; either way rebuild so renamed workouts show their new name.
    if (!mounted) return;
    setState(() {
      if (deleted == true) workouts.remove(workout);
    });
  }

  Future<void> _repeat(Workout workout) => repeatWorkout(context, workout);

  Future<void> _rename(Workout workout) async {
    final changed = await renameWorkoutFlow(context, workout);
    if (changed && mounted) setState(() {});
  }

  int _monthKey(DateTime d) => d.year * 12 + d.month;

  List<Widget> _buildItems(BuildContext context) {
    final items = <Widget>[];

    for (var i = 0; i < workouts.length; i++) {
      final workout = workouts[i];
      final isFirstOfMonth =
          i == 0 || _monthKey(workouts[i - 1].date) != _monthKey(workout.date);
      final nextSameMonth = i + 1 < workouts.length &&
          _monthKey(workouts[i + 1].date) == _monthKey(workout.date);

      if (isFirstOfMonth) {
        items.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 24, bottom: 4),
            child: Text(
              formatMonthHeader(workout.date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }

      items.add(
        _HistoryRow(
          workout: workout,
          showDivider: nextSameMonth,
          onTap: () => _openDetails(workout),
          onRepeat: () => _repeat(workout),
          onRename: () => _rename(workout),
          onDelete: () => confirmDelete(context, workout),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: workouts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 40,
                      color: context.colors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No workouts yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Finished workouts will show up here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: _buildItems(context),
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Workout workout;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onRepeat;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.workout,
    required this.showDivider,
    required this.onTap,
    required this.onRepeat,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final volume = workoutVolume(workout);
    final count = doneExercises(workout).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 12, left: 0),
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
                    workoutTitle(workout),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'exercise' : 'exercises'}'
                    '${volume > 0 ? ' · ${formatVolume(volume)}' : ''}',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(formatRelativeDate(workout.date), style: t.bodySmall),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: context.colors.muted,
              ),
              padding: EdgeInsets.zero,
              color: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'repeat') onRepeat();
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'repeat',
                  child: Row(
                    children: [
                      Icon(
                        Icons.replay_rounded,
                        size: 20,
                        color: context.colors.ink,
                      ),
                      const SizedBox(width: 8),
                      const Text('Repeat'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: context.colors.ink,
                      ),
                      const SizedBox(width: 8),
                      const Text('Rename'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: context.colors.error,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: context.colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
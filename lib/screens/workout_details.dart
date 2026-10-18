import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/workout_set.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import '../widgets/set_type_badge.dart';
import 'rename_workout_dialog.dart';
import 'template_actions.dart';
import 'text_prompt_dialog.dart';
import 'workout_actions.dart';

class WorkoutDetailsScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailsScreen({
    super.key,
    required this.workout,
  });

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen> {
  Workout get workout => widget.workout;

  Future<void> confirmDelete(BuildContext context) async {
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

    if (!context.mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> _editNote() async {
    final result = await showTextPrompt(
      context,
      title: 'Workout note',
      hint: 'How did it feel?',
      initial: workout.notes ?? '',
      confirmLabel: 'Save',
      maxLength: 500,
      maxLines: 6,
      capitalization: TextCapitalization.sentences,
    );

    if (result == null) return;

    final trimmed = result.trim();
    workout.notes = trimmed.isEmpty ? null : trimmed;

    await WorkoutStorage.updateWorkout(workout);
    WorkoutEvents.notifyChanged();

    if (mounted) setState(() {});
  }

  Widget _buildNote(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final note = (workout.notes ?? '').trim();

    return InkWell(
      onTap: _editNote,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes_rounded, size: 20, color: context.colors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                note.isEmpty ? 'Add a note' : note,
                style: note.isEmpty
                    ? t.bodySmall?.copyWith(fontSize: 14)
                    : t.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = doneExercises(workout).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Rename workout',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await renameWorkoutFlow(context, workout);
              if (changed && mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Delete workout',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => confirmDelete(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: doneExercises(workout).isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => repeatWorkout(context, workout),
                      icon: const Icon(Icons.replay_rounded, size: 20),
                      label: const Text('Repeat workout'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => saveWorkoutAsTemplate(context, workout),
                      icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                      label: const Text('Save as template'),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            hasName(workout)
                ? workout.name!.trim()
                : formatLongDate(workout.date),
            style: t.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${hasName(workout) ? '${formatLongDate(workout.date)} · ' : ''}'
            '${workoutDuration(workout) != null ? '${formatDuration(workoutDuration(workout)!)} · ' : ''}'
            '$count ${count == 1 ? 'exercise' : 'exercises'}',
            style: t.bodySmall?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          _SummaryRow(workout: workout),
          const SizedBox(height: 20),
          _buildNote(context),
          const SizedBox(height: 20),
          ...doneExercises(workout).map((workoutExercise) {
            final recordedSets = workoutExercise.sets
                .where(
                  (set) =>
                      set.isDone && (set.weight != null || set.reps != null),
                )
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workoutExercise.exercise.name,
                        style: t.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workoutExercise.supersetId != null
                            ? '${workoutExercise.exercise.muscleGroup} · Superset'
                            : workoutExercise.exercise.muscleGroup,
                        style: t.bodySmall,
                      ),
                      if ((workoutExercise.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: context.colors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                workoutExercise.notes!.trim(),
                                style: t.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: context.colors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (recordedSets.isEmpty)
                        Text(
                          'No sets recorded',
                          style: t.bodySmall?.copyWith(fontSize: 14),
                        )
                      else
                        ...recordedSets.asMap().entries.map((entry) {
                          final set = entry.value;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.colors.bg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${formatWeight(set.weight)} $unitLabel  ×  '
                                    '${set.reps ?? 0}',
                                    style: t.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (set.type != SetType.normal)
                                  SetTypeTag(type: set.type),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Workout workout;

  const _SummaryRow({required this.workout});

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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          stat('${doneExercises(workout).length}', 'Exercises'),
          divider(),
          stat('${workoutSetCount(workout)}', 'Sets'),
          divider(),
          stat(formatVolume(workoutVolume(workout)), 'Volume'),
        ],
      ),
    );
  }
}
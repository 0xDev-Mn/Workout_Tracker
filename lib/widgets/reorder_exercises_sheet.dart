import 'package:flutter/material.dart';

import '../models/workout_ex.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for dragging a workout's exercises into a new order.
class ReorderExercisesSheet extends StatefulWidget {
  final List<WorkoutExercise> exercises;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderExercisesSheet({
    super.key,
    required this.exercises,
    required this.onReorder,
  });

  @override
  State<ReorderExercisesSheet> createState() => _ReorderExercisesSheetState();
}

class _ReorderExercisesSheetState extends State<ReorderExercisesSheet> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final exercises = widget.exercises;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Reorder exercises', style: t.titleLarge),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Drag the handles. Moving an exercise out of a superset '
                'unlinks it.',
                style: t.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: exercises.length,
                onReorder: (oldIndex, newIndex) {
                  widget.onReorder(oldIndex, newIndex);
                  setState(() {});
                },
                itemBuilder: (context, i) {
                  final e = exercises[i];
                  final linked = e.supersetId != null;

                  return Container(
                    key: ObjectKey(e),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: i < exercises.length - 1
                          ? Border(
                              bottom: BorderSide(color: context.colors.border),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.exercise.name, style: t.titleMedium),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (linked) ...[
                                    const Icon(
                                      Icons.link_rounded,
                                      size: 14,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    linked
                                        ? '${e.exercise.muscleGroup} · Superset'
                                        : e.exercise.muscleGroup,
                                    style: t.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
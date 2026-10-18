import 'package:flutter/material.dart';

import '../services/goal_controller.dart';
import '../theme/app_theme.dart';

Future<void> showWeeklyGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _GoalSheet(),
  );
}

class _GoalSheet extends StatelessWidget {
  const _GoalSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Weekly goal', style: t.titleLarge),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'How many workouts do you want to do each week?',
                style: t.bodySmall,
              ),
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<int>(
              valueListenable: GoalController.weeklyGoal,
              builder: (context, goal, _) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final n in const [0, 1, 2, 3, 4, 5, 6, 7])
                      ChoiceChip(
                        label: Text(n == 0 ? 'Off' : '$n'),
                        selected: goal == n,
                        showCheckmark: false,
                        onSelected: (_) {
                          GoalController.set(n);
                          Navigator.pop(context);
                        },
                        selectedColor: AppColors.accent,
                        backgroundColor: context.colors.bg,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: goal == n
                                ? AppColors.accent
                                : context.colors.border,
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: goal == n
                              ? AppColors.onAccent
                              : context.colors.ink,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
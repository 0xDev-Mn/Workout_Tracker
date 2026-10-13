import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import 'workout_screen.dart';

/// Starts a new workout with the given exercises (and optional name).
/// Refuses politely if a workout is already in progress.
Future<void> startWorkoutFrom(
  BuildContext context, {
  required List<Exercise> exercises,
  String? name,
}) async {
  final active = await WorkoutStorage.getActiveWorkout();
  if (!context.mounted) return;

  if (active != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Workout in progress'),
        content: const Text(
          'Resume or finish your current workout before starting a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: context.colors.ink),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkoutScreen(exercises: exercises, name: name),
    ),
  );

  // Leaving mid-workout creates an active workout; finishing saves one.
  WorkoutEvents.notifyChanged();
}

/// Starts a new workout with the same name and exercises as [workout].
Future<void> repeatWorkout(BuildContext context, Workout workout) {
  return startWorkoutFrom(
    context,
    exercises: doneExercises(workout).map((e) => e.exercise).toList(),
    name: workout.name,
  );
}
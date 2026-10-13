import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/workout_template.dart';
import '../services/template_storage.dart';
import '../services/workout_events.dart';
import '../utils/workout_format.dart';
import 'text_prompt_dialog.dart';

/// Saves the exercises of a finished workout as a reusable routine.
Future<void> saveWorkoutAsTemplate(
  BuildContext context,
  Workout workout,
) async {
  final exercises = doneExercises(workout).map((e) => e.exercise).toList();
  if (exercises.isEmpty) return;

  final name = await showTextPrompt(
    context,
    title: 'Save as template',
    hint: 'Template name',
    initial: workout.name ?? '',
    confirmLabel: 'Save',
  );

  if (name == null || name.trim().isEmpty) return;

  await TemplateStorage.saveTemplate(
    WorkoutTemplate(name: name.trim(), exercises: exercises),
  );
  WorkoutEvents.notifyChanged();

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved "${name.trim()}" to your routines')),
  );
}
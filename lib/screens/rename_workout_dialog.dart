import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';

/// Asks for a new workout name, saves it and refreshes the other screens.
/// Returns true when the name actually changed.
Future<bool> renameWorkoutFlow(BuildContext context, Workout workout) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: workout.name ?? ''),
  );

  if (result == null) return false;

  final trimmed = result.trim();
  final newName = trimmed.isEmpty ? null : trimmed;

  if (newName == workout.name) return false;

  workout.name = newName;
  await WorkoutStorage.updateWorkout(workout);
  WorkoutEvents.notifyChanged();

  return true;
}

class _RenameDialog extends StatefulWidget {
  final String initial;

  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text('Rename workout'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Workout name',
          hintStyle: TextStyle(color: context.colors.hint),
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: context.colors.muted),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: TextButton.styleFrom(foregroundColor: context.colors.ink),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
import 'package:flutter/foundation.dart';

/// Call [notifyChanged] after saving or deleting workouts.
/// Screens that show workout data (like Home) listen to [changes]
/// and reload automatically.
class WorkoutEvents {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notifyChanged() {
    changes.value++;
  }
}
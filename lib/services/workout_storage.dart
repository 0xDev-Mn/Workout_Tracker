import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout.dart';

class WorkoutStorage {
  static const String _workoutsKey = 'workouts';
  static const String _activeWorkoutKey = 'active_workout';

  // -----------------------------
  // ACTIVE WORKOUT
  // -----------------------------

  static Future<void> saveActiveWorkout(Workout workout) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _activeWorkoutKey,
      jsonEncode(workout.toJson()),
    );
  }

  static Future<Workout?> getActiveWorkout() async {
    final prefs = await SharedPreferences.getInstance();

    final savedWorkout = prefs.getString(_activeWorkoutKey);

    if (savedWorkout == null) {
      return null;
    }

    return Workout.fromJson(
      jsonDecode(savedWorkout),
    );
  }

  static Future<void> clearActiveWorkout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_activeWorkoutKey);
  }

  // -----------------------------
  // COMPLETED WORKOUTS
  // -----------------------------

  static Future<void> saveWorkout(Workout workout) async {
    final prefs = await SharedPreferences.getInstance();

    final existingWorkouts =
        prefs.getStringList(_workoutsKey) ?? [];

    existingWorkouts.add(
      jsonEncode(workout.toJson()),
    );

    await prefs.setStringList(
      _workoutsKey,
      existingWorkouts,
    );
  }

  static Future<List<Workout>> getWorkouts() async {
    final prefs = await SharedPreferences.getInstance();

    final savedWorkouts =
        prefs.getStringList(_workoutsKey) ?? [];

    final workouts = savedWorkouts
        .map(
          (workout) => Workout.fromJson(
            jsonDecode(workout),
          ),
        )
        .toList();

    // Save the workouts again so older workouts
    // receive and permanently store their new IDs.
    await prefs.setStringList(
      _workoutsKey,
      workouts
          .map(
            (workout) => jsonEncode(workout.toJson()),
          )
          .toList(),
    );

    return workouts;
  }

  static Future<void> deleteWorkout(Workout workout) async {
    final prefs = await SharedPreferences.getInstance();

    final existingWorkouts =
        prefs.getStringList(_workoutsKey) ?? [];

    existingWorkouts.removeWhere((savedWorkout) {
      final decoded = Workout.fromJson(
        jsonDecode(savedWorkout),
      );

      return decoded.id == workout.id;
    });

    await prefs.setStringList(
      _workoutsKey,
      existingWorkouts,
    );
  }

  static Future<Workout?> getPreviousWorkout(
    String exerciseName,
    String currentWorkoutId,
  ) async {
    final workouts = await getWorkouts();

    final previousWorkouts = workouts.where(
      (workout) =>
          workout.id != currentWorkoutId &&
          workout.exercises.any(
            (exercise) =>
                exercise.exercise.name == exerciseName,
          ),
    ).toList();

    if (previousWorkouts.isEmpty) {
      return null;
    }

    previousWorkouts.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return previousWorkouts.first;
  }

}
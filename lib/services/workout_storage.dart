import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout.dart';

class WorkoutStorage {
  static const String _workoutsKey = 'workouts';
  static const String _activeWorkoutKey = 'active_workout';
  static const String _repairKey = 'repaired_unticked_sets_v1';

  // In-memory copy of the saved workouts so the tabs don't each re-parse all
  // the JSON on startup. Cleared whenever workouts are written.
  static List<Workout>? _cache;
  static Future<List<Workout>>? _loading;
  static int _version = 0;

  static void _invalidate() {
    _version++;
    _cache = null;
  }

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

    _invalidate();
  }

  static Future<List<Workout>> getWorkouts() async {
    final cached = _cache;
    if (cached != null) return List<Workout>.of(cached);

    // Several screens ask at the same time on startup: share one read.
    final startVersion = _version;
    final loading = _loading ??= _readWorkouts()
        .then((list) {
          if (_version == startVersion) _cache = list;
          return list;
        })
        .whenComplete(() => _loading = null);

    return List<Workout>.of(await loading);
  }

  static Future<List<Workout>> _readWorkouts() async {
    final prefs = await SharedPreferences.getInstance();

    final savedWorkouts =
        prefs.getStringList(_workoutsKey) ?? [];

    final workouts = <Workout>[];
    var needsMigration = false;

    // One-time repair: sets that have weight/reps but were never ticked
    // (saved before finishing counted them automatically) become counted.
    final repairUnticked = !(prefs.getBool(_repairKey) ?? false);

    for (final saved in savedWorkouts) {
      final json = Map<String, dynamic>.from(jsonDecode(saved));

      // Workouts saved by older versions of the app have no ID.
      if (json['id'] == null) {
        needsMigration = true;
      }

      // Sets saved before the "done" check existed have no isDone value.
      // Treat the ones that have data as done so old history keeps counting.
      for (final exercise in (json['exercises'] as List)) {
        for (final set in (exercise['sets'] as List)) {
          if (!set.containsKey('isDone')) {
            set['isDone'] = set['weight'] != null || set['reps'] != null;
            needsMigration = true;
          }

          if (repairUnticked &&
              set['isDone'] != true &&
              (set['weight'] != null || set['reps'] != null)) {
            set['isDone'] = true;
            needsMigration = true;
          }
        }
      }

      workouts.add(Workout.fromJson(json));
    }

    // Only write back when an old workout was just migrated (new ID or isDone),
    // so normal reads never touch storage.
    if (needsMigration) {
      await prefs.setStringList(
        _workoutsKey,
        workouts
            .map(
              (workout) => jsonEncode(workout.toJson()),
            )
            .toList(),
      );
    }

    if (repairUnticked) {
      await prefs.setBool(_repairKey, true);
    }

    return workouts;
  }

  /// Adds workouts that aren't saved yet (matched by id). Returns how many
  /// were added. The stored list is kept oldest-first, because History
  /// reverses it to show the newest first.
  static Future<int> mergeWorkouts(List<Workout> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_workoutsKey) ?? [];

    final ids = saved
        .map((s) => (jsonDecode(s) as Map<String, dynamic>)['id'])
        .toSet();

    var added = 0;
    for (final workout in incoming) {
      if (ids.contains(workout.id)) continue;

      saved.add(jsonEncode(workout.toJson()));
      ids.add(workout.id);
      added++;
    }

    if (added > 0) {
      final decorated = saved
          .map(
            (s) => MapEntry(
              DateTime.parse(
                (jsonDecode(s) as Map<String, dynamic>)['date'] as String,
              ),
              s,
            ),
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      await prefs.setStringList(
        _workoutsKey,
        decorated.map((e) => e.value).toList(),
      );
    }

    _invalidate();
    return added;
  }

  /// Overwrites a saved workout (matched by id), e.g. after renaming it.
  static Future<void> updateWorkout(Workout workout) async {
    final prefs = await SharedPreferences.getInstance();

    final existingWorkouts =
        prefs.getStringList(_workoutsKey) ?? [];

    final updated = existingWorkouts.map((saved) {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return json['id'] == workout.id
          ? jsonEncode(workout.toJson())
          : saved;
    }).toList();

    await prefs.setStringList(_workoutsKey, updated);

    _invalidate();
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

    _invalidate();
  }

  /// Heaviest weight ever logged (with reps) for each exercise, ignoring the
  /// workout with [excludeWorkoutId]. Keys are exercise names.
  static Future<Map<String, double>> getBestWeights({
    String? excludeWorkoutId,
  }) async {
    final workouts = await getWorkouts();
    final best = <String, double>{};

    for (final workout in workouts) {
      if (workout.id == excludeWorkoutId) continue;

      for (final e in workout.exercises) {
        for (final set in e.sets) {
          final weight = set.weight;
          final reps = set.reps;

          if (!set.isDone ||
              set.isWarmup ||
              weight == null ||
              reps == null ||
              weight <= 0 ||
              reps <= 0) {
            continue;
          }

          final current = best[e.exercise.name];
          if (current == null || weight > current) {
            best[e.exercise.name] = weight;
          }
        }
      }
    }

    return best;
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
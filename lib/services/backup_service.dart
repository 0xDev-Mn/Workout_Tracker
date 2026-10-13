import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_template.dart';
import 'exercise_storage.dart';
import 'template_storage.dart';
import 'workout_storage.dart';

/// Everything inside a backup file.
class BackupData {
  final List<Workout> workouts;
  final List<WorkoutTemplate> templates;
  final List<Exercise> customExercises;

  const BackupData({
    required this.workouts,
    required this.templates,
    required this.customExercises,
  });
}

/// What an import actually added.
class RestoreResult {
  final int workoutsAdded;
  final int templatesAdded;
  final int exercisesAdded;

  const RestoreResult({
    required this.workoutsAdded,
    required this.templatesAdded,
    required this.exercisesAdded,
  });

  String get message {
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';

    final parts = <String>[
      if (workoutsAdded > 0) plural(workoutsAdded, 'workout', 'workouts'),
      if (templatesAdded > 0) plural(templatesAdded, 'routine', 'routines'),
      if (exercisesAdded > 0)
        plural(exercisesAdded, 'custom exercise', 'custom exercises'),
    ];

    if (parts.isEmpty) {
      return 'Everything in that backup was already in the app.';
    }
    return 'Added ${parts.join(', ')}.';
  }
}

class BackupService {
  static const String appId = 'RepTracker';
  static const int version = 1;

  /// Writes all data to a temporary .json file and returns its path,
  /// or null when there is nothing to back up yet.
  static Future<String?> createBackupFile() async {
    final workouts = await WorkoutStorage.getWorkouts();
    final templates = await TemplateStorage.getTemplates();
    final exercises = await ExerciseStorage.getCustomExercises();

    if (workouts.isEmpty && templates.isEmpty && exercises.isEmpty) {
      return null;
    }

    final data = {
      'app': appId,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'workouts': workouts.map((w) => w.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
      'customExercises': exercises
          .map((e) => {'name': e.name, 'muscleGroup': e.muscleGroup})
          .toList(),
    };

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${dir.path}/reptracker-backup-$stamp.json');

    await file.writeAsString(jsonEncode(data));
    return file.path;
  }

  /// Reads a backup file's text. Returns null if it isn't a valid backup.
  static BackupData? tryParse(String text) {
    try {
      final decoded = jsonDecode(text);

      if (decoded is! Map<String, dynamic> || decoded['app'] != appId) {
        return null;
      }

      final fileVersion = decoded['version'];
      if (fileVersion is! int || fileVersion > version) return null;

      final workouts = (decoded['workouts'] as List? ?? [])
          .map((w) => Workout.fromJson(Map<String, dynamic>.from(w)))
          .toList();

      final templates = (decoded['templates'] as List? ?? [])
          .map((t) => WorkoutTemplate.fromJson(Map<String, dynamic>.from(t)))
          .toList();

      final exercises = (decoded['customExercises'] as List? ?? []).map((e) {
        final map = Map<String, dynamic>.from(e);
        return Exercise(
          name: map['name'] as String,
          muscleGroup: map['muscleGroup'] as String,
        );
      }).toList();

      return BackupData(
        workouts: workouts,
        templates: templates,
        customExercises: exercises,
      );
    } catch (_) {
      return null;
    }
  }

  /// Merges a backup into the app. Nothing is deleted or overwritten:
  /// workouts already present (same id) and routines / exercises with the
  /// same name are skipped.
  static Future<RestoreResult> restore(BackupData data) async {
    final workouts = await WorkoutStorage.mergeWorkouts(data.workouts);
    final templates = await TemplateStorage.mergeTemplates(data.templates);
    final exercises =
        await ExerciseStorage.mergeCustomExercises(data.customExercises);

    return RestoreResult(
      workoutsAdded: workouts,
      templatesAdded: templates,
      exercisesAdded: exercises,
    );
  }
}
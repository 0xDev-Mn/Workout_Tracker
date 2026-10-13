import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise.dart';

/// Exercises the user created themselves. They are saved on the device and
/// show up in the exercise library next to the built-in ones.
class ExerciseStorage {
  static const String _key = 'custom_exercises';

  static Future<List<Exercise>> getCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];

    return saved.map((item) {
      final json = Map<String, dynamic>.from(jsonDecode(item));
      return Exercise(
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
      );
    }).toList();
  }

  /// Adds exercises whose name isn't already in the custom list.
  /// Returns how many were added.
  static Future<int> mergeCustomExercises(List<Exercise> incoming) async {
    final existing = await getCustomExercises();
    final names = existing.map((e) => e.name.toLowerCase()).toSet();

    var added = 0;
    for (final exercise in incoming) {
      if (names.contains(exercise.name.toLowerCase())) continue;
      existing.add(exercise);
      names.add(exercise.name.toLowerCase());
      added++;
    }

    if (added > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        existing
            .map(
              (e) => jsonEncode({
                'name': e.name,
                'muscleGroup': e.muscleGroup,
              }),
            )
            .toList(),
      );
    }

    return added;
  }

  static Future<void> deleteCustomExercise(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];

    saved.removeWhere((item) {
      final json = Map<String, dynamic>.from(jsonDecode(item));
      return json['name'] == name;
    });

    await prefs.setStringList(_key, saved);
  }

  static Future<void> addCustomExercise(Exercise exercise) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];

    saved.add(
      jsonEncode({
        'name': exercise.name,
        'muscleGroup': exercise.muscleGroup,
      }),
    );

    await prefs.setStringList(_key, saved);
  }
}
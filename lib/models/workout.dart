import 'workout_ex.dart';

class Workout {
  final String id;
  final DateTime date;
  final List<WorkoutExercise> exercises;

  /// Optional name chosen by the user, e.g. "Push Day".
  String? name;

  /// When the workout was finished (null for older workouts).
  DateTime? endTime;

  Workout({
    String? id,
    required this.date,
    required this.exercises,
    this.name,
    this.endTime,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'exercises':
          exercises.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List)
        .map(
          (exercise) => WorkoutExercise.fromJson(
            Map<String, dynamic>.from(exercise),
          ),
        )
        .toList();

    return Workout(
      id: json['id'],
      name: json['name'] as String?,
      date: DateTime.parse(json['date']),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : null,
      exercises: exercises,
    );
  }
}
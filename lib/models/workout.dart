import 'workout_ex.dart';

class Workout {
  final String id;
  final DateTime date;
  final List<WorkoutExercise> exercises;

  Workout({
    String? id,
    required this.date,
    required this.exercises,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
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
      date: DateTime.parse(json['date']),
      exercises: exercises,
    );
  }
}
import 'exercise.dart';

/// A saved routine: a name plus the exercises to start a workout with.
class WorkoutTemplate {
  final String id;
  final String name;
  final List<Exercise> exercises;

  WorkoutTemplate({
    String? id,
    required this.name,
    required this.exercises,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'exercises': exercises
          .map((e) => {'name': e.name, 'muscleGroup': e.muscleGroup})
          .toList(),
    };
  }

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'] as String?,
      name: json['name'] as String,
      exercises: (json['exercises'] as List).map((item) {
        final map = Map<String, dynamic>.from(item);
        return Exercise(
          name: map['name'] as String,
          muscleGroup: map['muscleGroup'] as String,
        );
      }).toList(),
    );
  }
}
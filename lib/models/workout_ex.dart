import 'exercise.dart';
import 'workout_set.dart';

class WorkoutExercise {
  final Exercise exercise;
  final List<WorkoutSet> sets;

  /// Optional note about this exercise in this workout,
  /// e.g. "left shoulder felt tight".
  String? notes;

  /// Exercises that share the same id form a superset (done back to back).
  String? supersetId;

  WorkoutExercise({
    required this.exercise,
    List<WorkoutSet>? sets,
    this.notes,
    this.supersetId,
  }) : sets = sets ?? [];

  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exercise.name,
      'muscleGroup': exercise.muscleGroup,
      'notes': notes,
      'supersetId': supersetId,
      'sets': sets.map((set) => set.toJson()).toList(),
    };
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final exercise = Exercise(
      name: json['exerciseName'],
      muscleGroup: json['muscleGroup'],
    );

    final sets = (json['sets'] as List)
        .map(
          (set) => WorkoutSet.fromJson(
            Map<String, dynamic>.from(set),
          ),
        )
        .toList();

    return WorkoutExercise(
      exercise: exercise,
      notes: json['notes'] as String?,
      supersetId: json['supersetId'] as String?,
      sets: sets,
    );
  }
}
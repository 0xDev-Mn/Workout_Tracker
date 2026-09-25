import 'exercise.dart';
import 'workout_set.dart';

class WorkoutExercise {
  final Exercise exercise;
  final List<WorkoutSet> sets;

  WorkoutExercise({
    required this.exercise,
    List<WorkoutSet>? sets,
  }) : sets = sets ?? [];

  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exercise.name,
      'muscleGroup': exercise.muscleGroup,
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
      sets: sets,
    );
  }
}
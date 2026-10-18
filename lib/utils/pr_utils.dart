import '../models/workout.dart';
import '../models/workout_set.dart';

/// A personal record: a heavier weight than ever lifted before
/// for an exercise (with at least one rep).
class PersonalRecord {
  final String exerciseName;
  final double weight;
  final int reps;
  final double previousBest;

  const PersonalRecord({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.previousBest,
  });

  /// How much heavier than the previous best (rounded to avoid 0.0999...).
  double get increase =>
      double.parse((weight - previousBest).toStringAsFixed(2));
}

/// Index of the set that beats [previousBest], or null if none does.
/// When several sets beat it, the first set with the heaviest weight wins.
/// Exercises with no history ([previousBest] == null) never count, so the
/// very first time you do an exercise isn't flagged as a record.
int? prSetIndex(List<WorkoutSet> sets, double? previousBest) {
  if (previousBest == null) return null;

  int? bestIndex;
  var bestWeight = previousBest;

  for (var i = 0; i < sets.length; i++) {
    if (sets[i].isWarmup) continue; // warm-ups can't be records

    final weight = sets[i].weight;
    final reps = sets[i].reps;

    if (weight == null || reps == null || weight <= 0 || reps <= 0) continue;

    if (weight > bestWeight) {
      bestWeight = weight;
      bestIndex = i;
    }
  }

  return bestIndex;
}

/// All records set in [workout], given the best weight per exercise before it.
List<PersonalRecord> findRecords(
  Workout workout,
  Map<String, double> previousBest,
) {
  final records = <PersonalRecord>[];

  for (final e in workout.exercises) {
    final previous = previousBest[e.exercise.name];
    final sets = e.sets.where((s) => s.isDone).toList();
    final index = prSetIndex(sets, previous);

    if (index == null) continue;

    records.add(
      PersonalRecord(
        exerciseName: e.exercise.name,
        weight: sets[index].weight!,
        reps: sets[index].reps!,
        previousBest: previous!,
      ),
    );
  }

  return records;
}
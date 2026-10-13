import 'dart:math' as math;

import '../models/workout.dart';
import 'workout_format.dart';

/// Estimated one-rep max (Epley formula).
double estimateOneRm(double weight, int reps) {
  if (reps <= 1) return weight;
  return weight * (1 + reps / 30);
}

/// Monday of the week containing [d] (at midnight).
DateTime weekStartOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

class WeekBucket {
  final DateTime start;
  int workouts = 0;
  double volume = 0;

  WeekBucket(this.start);
}

/// The best set of one exercise in a single workout.
class SessionPoint {
  final DateTime date;
  final double topWeight;
  final int topWeightReps;
  final double oneRm;

  const SessionPoint({
    required this.date,
    required this.topWeight,
    required this.topWeightReps,
    required this.oneRm,
  });
}

class ExerciseRecord {
  final String name;
  final String muscleGroup;

  /// Oldest first.
  final List<SessionPoint> sessions;

  final double bestWeight;
  final int bestWeightReps;
  final double bestOneRm;
  final DateTime lastDate;

  const ExerciseRecord({
    required this.name,
    required this.muscleGroup,
    required this.sessions,
    required this.bestWeight,
    required this.bestWeightReps,
    required this.bestOneRm,
    required this.lastDate,
  });
}

class ProgressStats {
  final int totalWorkouts;
  final double totalVolume;
  final double avgPerWeek;

  /// Oldest first; the last bucket is the current week.
  final List<WeekBucket> weeks;

  /// Most recently trained first.
  final List<ExerciseRecord> records;

  const ProgressStats({
    required this.totalWorkouts,
    required this.totalVolume,
    required this.avgPerWeek,
    required this.weeks,
    required this.records,
  });

  static ProgressStats from(List<Workout> workouts, {int weekCount = 8}) {
    final thisWeek = weekStartOf(DateTime.now());

    final weeks = List.generate(
      weekCount,
      (i) => WeekBucket(
        DateTime(
          thisWeek.year,
          thisWeek.month,
          thisWeek.day - 7 * (weekCount - 1 - i),
        ),
      ),
    );
    final byWeek = {for (final w in weeks) w.start: w};

    final sorted = [...workouts]..sort((a, b) => a.date.compareTo(b.date));

    var totalVolume = 0.0;
    final sessionsByExercise = <String, List<SessionPoint>>{};
    final muscleByExercise = <String, String>{};

    for (final workout in sorted) {
      final volume = workoutVolume(workout);
      totalVolume += volume;

      final bucket = byWeek[weekStartOf(workout.date)];
      if (bucket != null) {
        bucket.workouts++;
        bucket.volume += volume;
      }

      for (final we in workout.exercises) {
        double? topWeight;
        var topReps = 0;
        var bestRm = 0.0;

        for (final set in we.sets) {
          if (!set.isDone) continue; // only sets marked done count
          final weight = set.weight;
          final reps = set.reps;
          if (weight == null || reps == null || weight <= 0 || reps <= 0) {
            continue;
          }

          if (topWeight == null ||
              weight > topWeight ||
              (weight == topWeight && reps > topReps)) {
            topWeight = weight;
            topReps = reps;
          }

          bestRm = math.max(bestRm, estimateOneRm(weight, reps));
        }

        if (topWeight == null) continue;

        sessionsByExercise.putIfAbsent(we.exercise.name, () => []).add(
              SessionPoint(
                date: workout.date,
                topWeight: topWeight,
                topWeightReps: topReps,
                oneRm: bestRm,
              ),
            );
        muscleByExercise[we.exercise.name] = we.exercise.muscleGroup;
      }
    }

    final records = sessionsByExercise.entries.map((entry) {
      final sessions = entry.value;

      var best = sessions.first;
      for (final s in sessions) {
        if (s.topWeight > best.topWeight ||
            (s.topWeight == best.topWeight &&
                s.topWeightReps > best.topWeightReps)) {
          best = s;
        }
      }

      return ExerciseRecord(
        name: entry.key,
        muscleGroup: muscleByExercise[entry.key] ?? '',
        sessions: sessions,
        bestWeight: best.topWeight,
        bestWeightReps: best.topWeightReps,
        bestOneRm: sessions.map((s) => s.oneRm).reduce(math.max),
        lastDate: sessions.last.date,
      );
    }).toList()
      ..sort((a, b) => b.lastDate.compareTo(a.lastDate));

    // Average workouts per week, counting only weeks since the first workout.
    var avgPerWeek = 0.0;
    if (sorted.isNotEmpty) {
      final firstWeek = weekStartOf(sorted.first.date);
      final weeksActive =
          (thisWeek.difference(firstWeek).inDays / 7).round() + 1;
      final window = weeksActive.clamp(1, weekCount);
      final inWindow = weeks
          .skip(weekCount - window)
          .fold<int>(0, (sum, w) => sum + w.workouts);
      avgPerWeek = inWindow / window;
    }

    return ProgressStats(
      totalWorkouts: workouts.length,
      totalVolume: totalVolume,
      avgPerWeek: avgPerWeek,
      weeks: weeks,
      records: records,
    );
  }
}
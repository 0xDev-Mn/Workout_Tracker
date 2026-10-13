import '../models/workout.dart';
import '../models/workout_ex.dart';

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _fullMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _fullWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exercises that have at least one set marked done.
List<WorkoutExercise> doneExercises(Workout w) =>
    w.exercises.where((e) => e.sets.any((s) => s.isDone)).toList();

/// Total weight x reps across all sets that are marked done.
double workoutVolume(Workout w) {
  var total = 0.0;
  for (final e in w.exercises) {
    for (final s in e.sets) {
      if (!s.isDone) continue;
      total += (s.weight ?? 0) * (s.reps ?? 0);
    }
  }
  return total;
}

/// Number of sets marked done that have a weight or reps filled in.
int workoutSetCount(Workout w) {
  var count = 0;
  for (final e in w.exercises) {
    count += e.sets
        .where((s) => s.isDone && (s.weight != null || s.reps != null))
        .length;
  }
  return count;
}

String formatVolume(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k kg';
  return '${v.round()} kg';
}

/// 60.0 -> "60", 62.5 -> "62.5"
String formatWeight(double? w) {
  final value = w ?? 0;
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}

/// "Today", "Yesterday", "3d ago", "Sep 23"
String formatRelativeDate(DateTime d) {
  final diff = _day(DateTime.now()).difference(_day(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '${diff}d ago';
  return '${_shortMonths[d.month - 1]} ${d.day}';
}

/// "Wednesday, Sep 23" (adds the year if it isn't this year)
String formatLongDate(DateTime d) {
  final base =
      '${_fullWeekdays[d.weekday - 1]}, ${_shortMonths[d.month - 1]} ${d.day}';
  return d.year == DateTime.now().year ? base : '$base, ${d.year}';
}

/// "September 2026"
String formatMonthHeader(DateTime d) =>
    '${_fullMonths[d.month - 1]} ${d.year}';

/// True when the user gave the workout a name.
bool hasName(Workout w) => (w.name ?? '').trim().isNotEmpty;

/// The user's name for the workout, otherwise "Bench Press, Squat +1".
String workoutTitle(Workout w) {
  if (hasName(w)) return w.name!.trim();

  final names = doneExercises(w).map((e) => e.exercise.name).toList();
  if (names.isEmpty) return 'Workout';
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2}';
}

/// "Sep 23"
String formatShortDate(DateTime d) =>
    '${_shortMonths[d.month - 1]} ${d.day}';

/// 950 -> "950", 1240 -> "1.2k"
String formatCompactNumber(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.round().toString();
}

/// How long the workout lasted, or null if unknown (older workouts) or
/// unrealistic (left open for a day or more).
Duration? workoutDuration(Workout w) {
  final end = w.endTime;
  if (end == null) return null;

  final d = end.difference(w.date);
  if (d.isNegative || d.inHours >= 24) return null;
  return d;
}

/// "1h 12m", "34 min", "<1 min"
String formatDuration(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes < 1) return '<1 min';
  return '${d.inMinutes} min';
}
class WorkoutSet {
  double? weight;
  int? reps;
  bool isDropSet;
  bool isDone;

  WorkoutSet({
    this.weight,
    this.reps,
    this.isDropSet = false,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'reps': reps,
      'isDropSet': isDropSet,
      'isDone': isDone,
    };
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      reps: json['reps'] as int?,
      isDropSet: json['isDropSet'] ?? false,
      // Workouts saved before this field existed simply load as "not done".
      isDone: json['isDone'] ?? false,
    );
  }
}
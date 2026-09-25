class WorkoutSet {
  double? weight;
  int? reps;
  bool isDropSet;

  WorkoutSet({
    this.weight,
    this.reps,
    this.isDropSet = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'reps': reps,
      'isDropSet': isDropSet,
    };
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      reps: json['reps'] as int?,
      isDropSet: json['isDropSet'] ?? false,
    );
  }
}
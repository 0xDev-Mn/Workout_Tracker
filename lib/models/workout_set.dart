enum SetType { normal, warmup, drop, failure }

extension SetTypeLabel on SetType {
  String get label {
    switch (this) {
      case SetType.normal:
        return 'Normal set';
      case SetType.warmup:
        return 'Warm-up';
      case SetType.drop:
        return 'Drop set';
      case SetType.failure:
        return 'Failure';
    }
  }
}

class WorkoutSet {
  double? weight;
  int? reps;
  SetType type;
  bool isDone;

  WorkoutSet({
    this.weight,
    this.reps,
    this.type = SetType.normal,
    this.isDone = false,
  });

  bool get isWarmup => type == SetType.warmup;
  bool get isDropSet => type == SetType.drop;

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'reps': reps,
      'type': type.name,
      // Kept so data stays readable by older versions of the app.
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
      type: _parseType(json),
      // Workouts saved before this field existed simply load as "not done".
      isDone: json['isDone'] ?? false,
    );
  }

  /// Older data only has isDropSet; newer data has a "type" name.
  static SetType _parseType(Map<String, dynamic> json) {
    final raw = json['type'];

    if (raw is String) {
      for (final candidate in SetType.values) {
        if (candidate.name == raw) return candidate;
      }
    }

    return json['isDropSet'] == true ? SetType.drop : SetType.normal;
  }
}
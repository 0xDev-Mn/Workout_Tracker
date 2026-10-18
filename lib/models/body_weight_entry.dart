/// One body-weight measurement. Weights are always stored in kg.
/// There is at most one entry per calendar day.
class BodyWeightEntry {
  final String id;
  final DateTime date; // midnight, local time
  final double kg;

  BodyWeightEntry({
    String? id,
    required DateTime date,
    required this.kg,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'kg': kg,
    };
  }

  factory BodyWeightEntry.fromJson(Map<String, dynamic> json) {
    return BodyWeightEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      kg: (json['kg'] as num).toDouble(),
    );
  }
}
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_weight_entry.dart';

class BodyWeightStorage {
  static const String _key = 'body_weights';

  /// All entries, oldest first.
  static Future<List<BodyWeightEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];

    final entries = saved
        .map(
          (item) => BodyWeightEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(item)),
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return entries;
  }

  /// Saves an entry. Another entry on the same day (or the same id) is
  /// replaced, so each day has at most one weight.
  static Future<void> save(BodyWeightEntry entry) async {
    final entries = await getEntries();

    entries.removeWhere((e) => e.id == entry.id || e.date == entry.date);
    entries.add(entry);

    await _write(entries);
  }

  static Future<void> delete(String id) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    await _write(entries);
  }

  /// Adds entries for days that have no entry yet. Returns how many.
  static Future<int> mergeEntries(List<BodyWeightEntry> incoming) async {
    final entries = await getEntries();
    final days = entries.map((e) => e.date).toSet();

    var added = 0;
    for (final entry in incoming) {
      if (days.contains(entry.date)) continue;
      entries.add(entry);
      days.add(entry.date);
      added++;
    }

    if (added > 0) await _write(entries);
    return added;
  }

  static Future<void> _write(List<BodyWeightEntry> entries) async {
    entries.sort((a, b) => a.date.compareTo(b.date));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
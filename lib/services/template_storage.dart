import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_template.dart';

class TemplateStorage {
  static const String _key = 'workout_templates';

  static Future<List<WorkoutTemplate>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];

    return saved
        .map(
          (item) => WorkoutTemplate.fromJson(
            Map<String, dynamic>.from(jsonDecode(item)),
          ),
        )
        .toList();
  }

  /// Saves a template. A template with the same name is replaced.
  static Future<void> saveTemplate(WorkoutTemplate template) async {
    final templates = await getTemplates();

    templates.removeWhere(
      (t) => t.name.toLowerCase() == template.name.toLowerCase(),
    );
    templates.add(template);

    await _write(templates);
  }

  /// Adds templates whose name isn't already used. Returns how many.
  static Future<int> mergeTemplates(List<WorkoutTemplate> incoming) async {
    final existing = await getTemplates();
    final names = existing.map((t) => t.name.toLowerCase()).toSet();

    var added = 0;
    for (final template in incoming) {
      if (names.contains(template.name.toLowerCase())) continue;
      existing.add(template);
      names.add(template.name.toLowerCase());
      added++;
    }

    if (added > 0) await _write(existing);
    return added;
  }

  static Future<void> deleteTemplate(String id) async {
    final templates = await getTemplates();
    templates.removeWhere((t) => t.id == id);
    await _write(templates);
  }

  static Future<void> _write(List<WorkoutTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      templates.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }
}
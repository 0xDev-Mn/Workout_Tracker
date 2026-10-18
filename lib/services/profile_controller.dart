import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's (optional) first name, used in the Home greeting.
class ProfileController {
  static const String _key = 'user_name';

  static final ValueNotifier<String> name = ValueNotifier<String>('');

  /// Call once in main() before runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name.value = prefs.getString(_key) ?? '';
  }

  static Future<void> set(String value) async {
    final trimmed = value.trim();
    name.value = trimmed;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }
}
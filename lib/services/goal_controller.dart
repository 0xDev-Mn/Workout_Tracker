import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many workouts the user wants to do each week (0 = no goal).
class GoalController {
  static const String _key = 'weekly_goal';
  static const int defaultGoal = 3;

  static final ValueNotifier<int> weeklyGoal =
      ValueNotifier<int>(defaultGoal);

  /// Call once in main() before runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    weeklyGoal.value = prefs.getInt(_key) ?? defaultGoal;
  }

  static Future<void> set(int goal) async {
    weeklyGoal.value = goal;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, goal);
  }
}
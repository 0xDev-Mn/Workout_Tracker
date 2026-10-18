import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether to show the first-launch welcome screens.
class OnboardingController {
  static const String _key = 'onboarding_done';

  /// True on a fresh install (set by [load]).
  static bool needsOnboarding = false;

  /// Call once in main() before runApp.
  ///
  /// Someone who already has data from before this screen existed is treated
  /// as done, so existing users never see it unless they ask for it
  /// (Settings -> Welcome tour).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_key);

    if (done != null) {
      needsOnboarding = !done;
      return;
    }

    final hasData = (prefs.getStringList('workouts') ?? []).isNotEmpty ||
        prefs.containsKey('active_workout') ||
        (prefs.getStringList('workout_templates') ?? []).isNotEmpty ||
        (prefs.getStringList('body_weights') ?? []).isNotEmpty ||
        prefs.containsKey('theme_mode') ||
        prefs.containsKey('weight_unit');

    needsOnboarding = !hasData;

    if (hasData) await prefs.setBool(_key, true);
  }

  static Future<void> markDone() async {
    needsOnboarding = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lb }

/// The weight unit shown on screen. Everything is always SAVED in kg;
/// this only converts what you see and type, so switching units never
/// changes your data.
class UnitController {
  static const String _key = 'weight_unit';
  static const double _lbPerKg = 2.2046226218;

  static final ValueNotifier<WeightUnit> unit =
      ValueNotifier<WeightUnit>(WeightUnit.kg);

  static bool get isLb => unit.value == WeightUnit.lb;
  static String get label => isLb ? 'lb' : 'kg';

  /// kg (as stored) -> the unit on screen.
  static double toDisplay(double kg) => isLb ? kg * _lbPerKg : kg;

  /// A number typed in the on-screen unit -> kg (as stored).
  /// Rounded to 4 decimals so typing the same value twice gives
  /// exactly the same stored number (important for record checks).
  static double fromDisplay(double value) {
    if (!isLb) return value;
    return double.parse((value / _lbPerKg).toStringAsFixed(4));
  }

  /// Call once in main() before runApp.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    unit.value =
        prefs.getString(_key) == 'lb' ? WeightUnit.lb : WeightUnit.kg;
  }

  static Future<void> set(WeightUnit newUnit) async {
    unit.value = newUnit;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newUnit.name);
  }
}
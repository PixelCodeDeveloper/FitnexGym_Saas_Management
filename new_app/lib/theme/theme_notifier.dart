import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _key = 'app_theme_mode';

  ThemeNotifier() : super(ThemeMode.dark);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      value = ThemeMode.light;
    } else {
      value = ThemeMode.dark;
    }
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (value == ThemeMode.dark) {
      value = ThemeMode.light;
      await prefs.setString(_key, 'light');
    } else {
      value = ThemeMode.dark;
      await prefs.setString(_key, 'dark');
    }
  }

  bool get isDark => value == ThemeMode.dark;
}

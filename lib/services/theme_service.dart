import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;
  
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeKey);
      if (savedMode != null) {
        _themeMode = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }
  
  Future<void> toggleTheme() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}

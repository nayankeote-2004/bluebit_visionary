import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  // Singleton pattern
  static final ThemeService _instance = ThemeService._internal();
  
  factory ThemeService() {
    return _instance;
  }
  
  ThemeService._internal();
  
  // Key for storing theme preference
  static const String _themeKey = 'isDarkMode';
  
  // Theme mode (default to light)
  ThemeMode _themeMode = ThemeMode.light;
  
  // Get current theme mode
  ThemeMode get themeMode => _themeMode;
  
  // Check if dark mode is enabled
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  // Listeners for theme changes
  final List<Function(ThemeMode)> _listeners = [];
  
  // Initialize theme from preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_themeKey) ?? false; // Default to light theme
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
  
  // Toggle theme mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    
    // Notify listeners
    _notifyListeners();
  }
  
  // Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    
    // Notify listeners
    _notifyListeners();
  }
  
  // Add a listener
  void addListener(Function(ThemeMode) listener) {
    _listeners.add(listener);
  }
  
  // Remove a listener
  void removeListener(Function(ThemeMode) listener) {
    _listeners.remove(listener);
  }
  
  // Notify all listeners
  void _notifyListeners() {
    for (var listener in _listeners) {
      listener(_themeMode);
    }
  }
}
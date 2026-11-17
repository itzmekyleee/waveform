import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider(this._storage) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  void _loadTheme() {
    final mode = _storage.themeMode;
    switch (mode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    switch (mode) {
      case ThemeMode.light:
        await _storage.setThemeMode('light');
        break;
      case ThemeMode.dark:
        await _storage.setThemeMode('dark');
        break;
      case ThemeMode.system:
        await _storage.setThemeMode('system');
        break;
    }
  }
}

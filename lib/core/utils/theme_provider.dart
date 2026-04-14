import 'package:flutter/material.dart';

/// Gestiona el modo claro/oscuro de toda la aplicación.
/// Úsalo con [ChangeNotifierProvider] en el nivel raíz (KolektaApp).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Alterna entre modo claro y oscuro.
  void toggle() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
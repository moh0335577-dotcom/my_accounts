import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final bool isLocked;

  SettingsState({
    required this.themeMode,
    required this.locale,
    this.isLocked = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? isLocked,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          themeMode: _loadTheme(_prefs),
          locale: _loadLocale(_prefs),
          isLocked: _prefs.getBool('app_locked') ?? false,
        ));

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final theme = prefs.getString('theme_mode');
    if (theme == 'light') return ThemeMode.light;
    if (theme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  static Locale _loadLocale(SharedPreferences prefs) {
    final lang = prefs.getString('language_code');
    if (lang == 'en') return const Locale('en');
    return const Locale('ar');
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString('theme_mode', mode.name);
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
    _prefs.setString('language_code', locale.languageCode);
  }

  void toggleLock(bool locked) {
    state = state.copyWith(isLocked: locked);
    _prefs.setBool('app_locked', locked);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});



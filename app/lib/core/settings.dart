import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Se sobreescribe en main() con la instancia ya cargada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider no fue inicializado'),
);

class DemoModeController extends Notifier<bool> {
  static const _key = 'demo_mode';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool enabled) {
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

final demoModeProvider = NotifierProvider<DemoModeController, bool>(DemoModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.where((m) => m.name == stored).firstOrNull ?? ThemeMode.system;
  }

  void set(ThemeMode mode) {
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

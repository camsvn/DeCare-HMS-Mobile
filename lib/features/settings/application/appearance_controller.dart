import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';

/// The user's appearance choice, read from and written to prefs. Anything
/// other than a stored `'light'` or `'dark'` — including no value at all —
/// means follow the platform.
class AppearanceController extends Notifier<ThemeMode> {
  static const prefsKey = 'appearance';

  @override
  ThemeMode build() {
    switch (ref.watch(sharedPreferencesProvider).getString(prefsKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, _stored(mode));
  }

  static String _stored(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final appearanceProvider =
    NotifierProvider<AppearanceController, ThemeMode>(AppearanceController.new);

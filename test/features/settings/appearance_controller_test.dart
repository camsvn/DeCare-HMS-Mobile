import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> containerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to system when nothing is stored', () async {
    final container = await containerWith({});
    expect(container.read(appearanceProvider), ThemeMode.system);
  });

  test('reads the stored choice', () async {
    expect((await containerWith({'appearance': 'light'})).read(appearanceProvider), ThemeMode.light);
    expect((await containerWith({'appearance': 'dark'})).read(appearanceProvider), ThemeMode.dark);
    expect((await containerWith({'appearance': 'system'})).read(appearanceProvider), ThemeMode.system);
  });

  test('falls back to system for an unknown stored value', () async {
    final container = await containerWith({'appearance': 'sepia'});
    expect(container.read(appearanceProvider), ThemeMode.system);
  });

  test('set persists the choice and rebuilds', () async {
    final container = await containerWith({});
    await container.read(appearanceProvider.notifier).set(ThemeMode.dark);
    expect(prefs.getString('appearance'), 'dark');
    expect(container.read(appearanceProvider), ThemeMode.dark);

    await container.read(appearanceProvider.notifier).set(ThemeMode.light);
    expect(prefs.getString('appearance'), 'light');
    expect(container.read(appearanceProvider), ThemeMode.light);

    await container.read(appearanceProvider.notifier).set(ThemeMode.system);
    expect(prefs.getString('appearance'), 'system');
    expect(container.read(appearanceProvider), ThemeMode.system);
  });
}

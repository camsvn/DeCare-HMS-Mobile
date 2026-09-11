import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('off on a device that has never asked for it', () async {
    final container = await containerWith({});

    expect(container.read(captureGridProvider), isFalse);
  });

  test('toggle flips it and writes it down', () async {
    final container = await containerWith({});

    await container.read(captureGridProvider.notifier).toggle();

    expect(container.read(captureGridProvider), isTrue);
    expect(prefs.getBool('capture_grid'), isTrue);

    await container.read(captureGridProvider.notifier).toggle();

    expect(container.read(captureGridProvider), isFalse);
    expect(prefs.getBool('capture_grid'), isFalse);
  });

  test('comes back on for a device that left it on', () async {
    // Framing with a grid is a habit, not a per-session choice: asking for it
    // again on every visit to the camera is what makes a setting unused.
    final container = await containerWith({'capture_grid': true});

    expect(container.read(captureGridProvider), isTrue);
  });
}

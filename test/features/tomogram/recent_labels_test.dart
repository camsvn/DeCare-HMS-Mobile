import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('RecentLabelsRepository', () {
    test('reads an empty list when nothing has been remembered', () {
      expect(RecentLabelsRepository(prefs).read(), isEmpty);
    });

    test('puts the newest call first, keeping the order it was given', () async {
      final repo = RecentLabelsRepository(prefs);

      await repo.remember(['Left forearm']);
      await repo.remember(['left FOREARM', 'Back']);

      // The second call is the most recent, in the order given, and the
      // case-insensitive duplicate of the first call is gone.
      expect(repo.read(), ['left FOREARM', 'Back']);
    });

    test('trims and drops blanks', () async {
      final repo = RecentLabelsRepository(prefs);

      await repo.remember(['  Left forearm  ', '', '   ', 'Back']);

      expect(repo.read(), ['Left forearm', 'Back']);
    });

    test('never stores a label too long to offer', () async {
      final repo = RecentLabelsRepository(prefs);
      final long = 'x' * (suggestionMaxLength + 1);

      await repo.remember([long, 'Back']);

      expect(repo.read(), ['Back']);
    });

    test('stops offering a long label a previous version stored', () async {
      // Filtered on the way out as well as in, so a device that remembered a
      // sentence before the cap existed stops offering it with no migration.
      final long = 'x' * (suggestionMaxLength + 1);
      await prefs.setStringList(RecentLabelsRepository.key, [long, 'Back']);

      expect(RecentLabelsRepository(prefs).read(), ['Back']);
    });

    test('forget drops a label case-insensitively and persists', () async {
      final repo = RecentLabelsRepository(prefs);
      await repo.remember(['Left forearm', 'BACK', 'Neck']);

      await repo.forget('  back  ');

      expect(repo.read(), ['Left forearm', 'Neck']);
      expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm', 'Neck']);
      // A label that was never there is not an error.
      await repo.forget('Scalp');
      expect(repo.read(), ['Left forearm', 'Neck']);
    });

    test('keeps the newest of two labels that differ only in case', () async {
      final repo = RecentLabelsRepository(prefs);

      await repo.remember(['BACK', 'back', 'Neck']);

      expect(repo.read(), ['BACK', 'Neck']);
    });

    test('caps at ten, dropping the oldest', () async {
      final repo = RecentLabelsRepository(prefs);
      for (var i = 1; i <= 12; i++) {
        await repo.remember(['label $i']);
      }

      final labels = repo.read();
      expect(labels, hasLength(recentLabelsCap));
      expect(labels.first, 'label 12');
      expect(labels.last, 'label 3');
      expect(labels, isNot(contains('label 1')));
      expect(labels, isNot(contains('label 2')));
    });

    test('persists, so a new repository over the same prefs reads the same', () async {
      await RecentLabelsRepository(prefs).remember(['Left forearm', 'Back']);

      expect(RecentLabelsRepository(prefs).read(), ['Left forearm', 'Back']);
      expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm', 'Back']);
    });
  });

  group('recentLabelsProvider', () {
    ProviderContainer containerWith(SharedPreferences prefs) {
      final container = ProviderContainer(retry: noRetry, overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      return container;
    }

    test('starts from what was persisted', () async {
      await RecentLabelsRepository(prefs).remember(['Back']);

      expect(containerWith(prefs).read(recentLabelsProvider), ['Back']);
    });

    test('remember updates the state and persists', () async {
      final container = containerWith(prefs);

      await container.read(recentLabelsProvider.notifier).remember(['Left forearm', 'Back']);

      expect(container.read(recentLabelsProvider), ['Left forearm', 'Back']);
      expect(RecentLabelsRepository(prefs).read(), ['Left forearm', 'Back']);

      await container.read(recentLabelsProvider.notifier).remember(['back']);

      expect(container.read(recentLabelsProvider), ['back', 'Left forearm']);
    });

    test('forget updates the state and persists', () async {
      // A guess that keeps coming back is worse than no guess.
      final container = containerWith(prefs);
      await container.read(recentLabelsProvider.notifier).remember(['Left forearm', 'Back']);

      await container.read(recentLabelsProvider.notifier).forget('LEFT FOREARM');

      expect(container.read(recentLabelsProvider), ['Back']);
      expect(RecentLabelsRepository(prefs).read(), ['Back']);
    });
  });
}

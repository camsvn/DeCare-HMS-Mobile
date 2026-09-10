import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

void main() {
  group('mergeSuggestions', () {
    test('history first, then the recent labels it does not already carry', () {
      final merged = mergeSuggestions(
        ['Left forearm', 'Left forearm ', 'BACK'],
        ['back', 'Neck'],
      );

      // Trimmed, deduped case-insensitively keeping the first (newest) form.
      expect(merged, ['Left forearm', 'BACK', 'Neck']);
    });

    test('drops anything too long to be a body site', () {
      // Some narrations are a sentence, or a paste of somebody's notes. As a
      // chip that would wrap over two lines and push the row off the screen,
      // and nobody would pick it: dropped rather than truncated, which would
      // offer text that is not what it says.
      final long = 'x' * (suggestionMaxLength + 1);
      final atCap = 'y' * suggestionMaxLength;

      expect(mergeSuggestions([long, 'Back'], [atCap]), ['Back', atCap]);
      // Measured after trimming, so trailing spaces do not disqualify one.
      expect(mergeSuggestions(['  $atCap  '], const []), [atCap]);
    });

    test('drops blanks', () {
      expect(mergeSuggestions(['', '  ', 'Back'], ['   ', 'Neck']), ['Back', 'Neck']);
    });

    test('caps at eight by default, keeping the newest', () {
      final history = [for (var i = 1; i <= 10; i++) 'h$i'];

      final merged = mergeSuggestions(history, ['r1']);

      expect(merged, ['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h7', 'h8']);
    });

    test('honours a smaller cap', () {
      expect(mergeSuggestions(['a', 'b'], ['c'], max: 2), ['a', 'b']);
    });

    test('empty inputs give an empty list', () {
      expect(mergeSuggestions(const [], const []), isEmpty);
    });
  });

  group('descriptionSuggestionsProvider', () {
    late MockTomogramHistoryApi history;
    late SharedPreferences prefs;

    TomogramSet setWith(int id, List<String> narrations) => TomogramSet(
          id: id,
          dateTime: DateTime(2026, 9, 8, 14, 32),
          doctorId: 1,
          tomogramTypeId: 1,
          details: [
            for (var i = 0; i < narrations.length; i++)
              TomogramSetDetail(id: i, tomogramPartId: i, narration: narrations[i]),
          ],
        );

    setUp(() async {
      history = MockTomogramHistoryApi();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<ProviderContainer> containerWith(List<String> recent) async {
      // Given newest first, so `remember` is handed them in that order.
      await RecentLabelsRepository(prefs).remember(recent);
      final container = ProviderContainer(overrides: [
        tomogramHistoryApiProvider.overrideWithValue(history),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('the uploaded narrations in the order the API returned them, then the recent labels', () async {
      when(() => history.list(42)).thenAnswer((_) async => [setWith(9, ['a']), setWith(8, ['b'])]);
      final container = await containerWith(['c', 'a']);
      container.listen(descriptionSuggestionsProvider(42), (_, __) {});

      await container.read(tomogramHistoryProvider(42).future);

      // The API already returns the sets newest first; the provider does not
      // re-sort. 'a' is already in the history, so only 'c' is added.
      expect(container.read(descriptionSuggestionsProvider(42)), ['a', 'b', 'c']);
    });

    test('only the recent labels while the history has not arrived', () async {
      when(() => history.list(42)).thenAnswer((_) async => [setWith(9, ['a'])]);
      final container = await containerWith(['c']);

      expect(container.read(descriptionSuggestionsProvider(42)), ['c']);
    });

    test('only the recent labels when the history fetch failed', () async {
      when(() => history.list(42)).thenThrow(const TimeoutFailure());
      final container = await containerWith(['c']);
      container.listen(descriptionSuggestionsProvider(42), (_, __) {});

      await expectLater(container.read(tomogramHistoryProvider(42).future), throwsA(isA<TimeoutFailure>()));

      expect(container.read(descriptionSuggestionsProvider(42)), ['c']);
    });

    test('a new recent label shows up without refetching the history', () async {
      when(() => history.list(42)).thenAnswer((_) async => [setWith(9, ['a'])]);
      final container = await containerWith(const []);
      container.listen(descriptionSuggestionsProvider(42), (_, __) {});
      await container.read(tomogramHistoryProvider(42).future);
      expect(container.read(descriptionSuggestionsProvider(42)), ['a']);

      await container.read(recentLabelsProvider.notifier).remember(['Neck']);

      expect(container.read(descriptionSuggestionsProvider(42)), ['a', 'Neck']);
      verify(() => history.list(42)).called(1);
    });
  });
}

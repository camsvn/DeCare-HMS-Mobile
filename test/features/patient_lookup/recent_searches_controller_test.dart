import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

Patient p(int id) => Patient(id: id, opid: id * 10, name: 'P$id');

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(retry: noRetry, overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
  });

  test('add puts newest first, dedupes by id and caps at 10', () {
    final c = container.read(recentSearchesControllerProvider.notifier);
    for (var i = 1; i <= 12; i++) {
      c.add(p(i));
    }
    var list = container.read(recentSearchesControllerProvider);
    expect(list.length, recentSearchesCap);
    expect(list.first, p(12));
    expect(list.last, p(3));
    c.add(p(5));
    list = container.read(recentSearchesControllerProvider);
    expect(list.first, p(5));
    expect(list.where((x) => x.id == 5).length, 1);
    expect(list.length, recentSearchesCap);
  });

  test('remove and clear persist', () async {
    final c = container.read(recentSearchesControllerProvider.notifier);
    c.add(p(1));
    c.add(p(2));
    c.remove(1);
    expect(container.read(recentSearchesControllerProvider), [p(2)]);
    expect(container.read(recentSearchesRepositoryProvider).read(), [p(2)]);
    c.clear();
    expect(container.read(recentSearchesControllerProvider), isEmpty);
    expect(container.read(recentSearchesRepositoryProvider).read(), isEmpty);
  });
}

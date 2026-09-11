import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

void main() {
  late MockHealthCheckApi api;
  late ProviderContainer container;

  Future<void> setUpWith({String? savedUrl}) async {
    SharedPreferences.setMockInitialValues(savedUrl == null ? {} : {'server_url': savedUrl});
    final prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    container = ProviderContainer(retry: noRetry, overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  }

  test('build reads saved url', () async {
    await setUpWith(savedUrl: 'http://saved');
    expect(await container.read(serverConfigControllerProvider.future), 'http://saved');
  });

  test('connect rejects invalid url without calling the network', () async {
    await setUpWith();
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('not a url');
    final state = container.read(serverConfigControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvalidServerUrlException>());
    verifyNever(() => api.check(any()));
  });

  test('connect saves normalized url on healthy server', () async {
    await setUpWith();
    when(() => api.check(any())).thenAnswer((_) async {});
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('decare.team/');
    verify(() => api.check('http://decare.team')).called(1);
    expect(container.read(serverConfigControllerProvider).value, 'http://decare.team');
    expect(container.read(serverConfigRepositoryProvider).read(), 'http://decare.team');
  });

  test('connect keeps previous url and exposes failure when health check fails', () async {
    await setUpWith(savedUrl: 'http://old');
    when(() => api.check(any())).thenThrow(const CannotConnectFailure());
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('http://new.example.com');
    final state = container.read(serverConfigControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<CannotConnectFailure>());
    expect(state.value, 'http://old');
    expect(container.read(serverConfigRepositoryProvider).read(), 'http://old');
  });

  test('reset clears the url', () async {
    await setUpWith(savedUrl: 'http://old');
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).reset();
    expect(container.read(serverConfigControllerProvider).value, isNull);
    expect(container.read(serverConfigRepositoryProvider).read(), isNull);
  });
}

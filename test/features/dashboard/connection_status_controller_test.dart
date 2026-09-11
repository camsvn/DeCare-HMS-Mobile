import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/dashboard/dashboard.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

void main() {
  late MockHealthCheckApi api;
  late FakeConnectivityService connectivity;
  late ProviderContainer container;

  Future<void> settle() async {
    // Two turns: one for the connectivity check, one for the health check.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://hms.example.com'});
    final prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    when(() => api.check(any())).thenAnswer((_) async {});
    connectivity = FakeConnectivityService();
    container = ProviderContainer(retry: noRetry, overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
      connectivityServiceProvider.overrideWithValue(connectivity),
    ]);
    // Keep the provider alive for the whole test, as the dashboard does.
    container.listen(connectionStatusProvider, (_, _) {});
    addTearDown(container.dispose);
    addTearDown(connectivity.close);
  });

  test('online and a healthy server reads as connected', () async {
    expect(await container.read(connectionStatusProvider.future), isTrue);
    verify(() => api.check('http://hms.example.com')).called(1);
  });

  test('offline reads as unreachable without asking the server', () async {
    connectivity.online = false;
    expect(await container.read(connectionStatusProvider.future), isFalse);
    verifyNever(() => api.check(any()));
  });

  test('losing the network flips the status without a health check', () async {
    expect(await container.read(connectionStatusProvider.future), isTrue);
    connectivity.emit(false);
    await settle();
    expect(container.read(connectionStatusProvider).value, isFalse);
    verify(() => api.check(any())).called(1);
  });

  test('regaining the network runs the health check again', () async {
    connectivity.online = false;
    expect(await container.read(connectionStatusProvider.future), isFalse);
    connectivity.emit(true);
    await settle();
    expect(container.read(connectionStatusProvider).value, isTrue);
    verify(() => api.check(any())).called(1);
  });

  test('refresh re-runs the health check and reports a server that went down', () async {
    expect(await container.read(connectionStatusProvider.future), isTrue);
    when(() => api.check(any())).thenThrow(Exception('down'));
    container.read(connectionStatusProvider.notifier).refresh();
    await settle();
    expect(container.read(connectionStatusProvider).value, isFalse);
    verify(() => api.check(any())).called(2);
  });

  test('a health check failure while online reads as unreachable', () async {
    when(() => api.check(any())).thenThrow(Exception('down'));
    expect(await container.read(connectionStatusProvider.future), isFalse);
  });
}

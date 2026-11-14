import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/network/server_reachability.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';

import '../../helpers/fake_connectivity.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeConnectivityService connectivity;

  ProviderContainer containerFor({String? url = 'http://x'}) {
    final container = ProviderContainer(retry: noRetry, overrides: [
      serverUrlProvider.overrideWithValue(url),
      accessTokenProvider.overrideWithValue(null),
      refreshAccessTokenProvider.overrideWithValue(() async => null),
      connectivityServiceProvider.overrideWithValue(connectivity),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    connectivity = FakeConnectivityService();
    addTearDown(connectivity.close);
  });

  test('starts unknown', () {
    expect(containerFor().read(serverReachabilityProvider), isNull);
  });

  group('the shared client', () {
    test('records a response as reachable', () async {
      final container = containerFor();
      container.read(dioProvider).httpClientAdapter = FakeHttpAdapter.status(200);
      await container.read(dioProvider).get<dynamic>('/opregister');
      expect(container.read(serverReachabilityProvider), isTrue);
    });

    test('records a failed connection as unreachable', () async {
      final container = containerFor();
      container.read(dioProvider).httpClientAdapter = FakeHttpAdapter.failing(DioExceptionType.connectionError);
      await expectLater(container.read(dioProvider).get<dynamic>('/opregister'), throwsA(isA<DioException>()));
      expect(container.read(serverReachabilityProvider), isFalse);
    });

    test('fails at once when the device is offline', () async {
      connectivity.online = false;
      final container = containerFor();
      final adapter = FakeHttpAdapter.status(200);
      container.read(dioProvider).httpClientAdapter = adapter;
      await expectLater(
        container.read(dioProvider).get<dynamic>('/opregister'),
        throwsA(isA<DioException>().having(ApiFailure.from, 'failure', isA<OfflineFailure>())),
      );
      expect(adapter.paths, isEmpty);
      expect(container.read(serverReachabilityProvider), isFalse);
    });
  });

  group('recheck', () {
    test('asks the health endpoint and records that the server answered', () async {
      final container = containerFor();
      final adapter = FakeHttpAdapter.status(200);
      container.read(dioProvider).httpClientAdapter = adapter;
      container.read(serverReachabilityProvider.notifier).report(false);

      await container.read(serverReachabilityProvider.notifier).recheck();

      expect(adapter.paths, ['/api/auth/healthcheck']);
      expect(container.read(serverReachabilityProvider), isTrue);
    });

    test('records a server that is still down without throwing', () async {
      final container = containerFor();
      container.read(dioProvider).httpClientAdapter = FakeHttpAdapter.failing(DioExceptionType.connectionTimeout);
      container.read(serverReachabilityProvider.notifier).report(true);

      await container.read(serverReachabilityProvider.notifier).recheck();

      expect(container.read(serverReachabilityProvider), isFalse);
    });

    test('with no server configured does nothing and does not throw', () async {
      final container = containerFor(url: null);
      await container.read(serverReachabilityProvider.notifier).recheck();
      expect(container.read(serverReachabilityProvider), isNull);
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockAuthApi api;
  late InMemorySecureStore store;
  late ProviderContainer container;

  setUp(() {
    api = MockAuthApi();
    store = InMemorySecureStore();
    container = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      authApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  });

  test('build reads persisted session', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    final s = await container.read(sessionControllerProvider.future);
    expect(s?.accessToken, 'a');
  });

  test('login stores session on success', () async {
    when(() => api.login('u', 'p'))
        .thenAnswer((_) async => const Session(accessToken: 'a', refreshToken: 'r'));
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).login('u', 'p');
    expect(container.read(sessionControllerProvider).value?.refreshToken, 'r');
    expect(await store.read('refresh_token'), 'r');
  });

  test('login exposes failure and keeps session null', () async {
    when(() => api.login(any(), any())).thenThrow(const UnauthorizedFailure());
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).login('u', 'bad');
    final state = container.read(sessionControllerProvider);
    expect(state.error, isA<UnauthorizedFailure>());
    expect(state.value, isNull);
  });

  test('logout clears session and store', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).logout();
    expect(container.read(sessionControllerProvider).value, isNull);
    expect(await store.read('access_token'), isNull);
  });

  test('refreshAccessToken stores the new token', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    when(() => api.refresh('r')).thenAnswer((_) async => 'A2');
    await container.read(sessionControllerProvider.future);

    final token = await container.read(sessionControllerProvider.notifier).refreshAccessToken();
    expect(token, 'A2');
    expect(container.read(sessionControllerProvider).value?.accessToken, 'A2');
    expect(container.read(sessionControllerProvider).value?.refreshToken, 'r');
    expect(await store.read('access_token'), 'A2');
    expect(await store.read('refresh_token'), 'r');
  });

  test('refreshAccessToken returns null on failure without clearing the session', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    when(() => api.refresh(any())).thenThrow(const UnauthorizedFailure());
    await container.read(sessionControllerProvider.future);

    final token = await container.read(sessionControllerProvider.notifier).refreshAccessToken();
    expect(token, isNull);
    expect(container.read(sessionControllerProvider).value?.accessToken, 'a');
    expect(await store.read('access_token'), 'a');
    expect(await store.read('refresh_token'), 'r');
  });

  test('refreshAccessToken returns null when there is no session', () async {
    await container.read(sessionControllerProvider.future);
    expect(await container.read(sessionControllerProvider.notifier).refreshAccessToken(), isNull);
    verifyNever(() => api.refresh(any()));
  });

  group('DioAuthApi', () {
    test('posts credentials and parses tokens', () async {
      final dio = MockDio();
      when(() => dio.post<dynamic>('/auth/login', data: {'username': 'u', 'password': 'p'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/login'),
                statusCode: 200,
                data: {
                  'status': 'success',
                  'data': {'id': 1, 'username': 'u', 'accessToken': 'A', 'refreshToken': 'R'},
                },
              ));
      final s = await DioAuthApi(dio).login('u', 'p');
      expect(s.accessToken, 'A');
      expect(s.refreshToken, 'R');
    });

    test('maps 404 to UnauthorizedFailure', () async {
      final dio = MockDio();
      final req = RequestOptions(path: '/auth/login');
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenThrow(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 404, data: {'status': 'fail', 'data': 'Invalid Credentials'}),
      ));
      expect(() => DioAuthApi(dio).login('u', 'p'), throwsA(isA<UnauthorizedFailure>()));
    });

    test('refresh posts the refresh token and returns the new access token', () async {
      final dio = MockDio();
      when(() => dio.post<dynamic>('/auth/refresh', data: {'refreshToken': 'R'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/refresh'),
                statusCode: 200,
                data: {
                  'status': 'success',
                  'data': {'accessToken': 'A2'},
                },
              ));
      expect(await DioAuthApi(dio).refresh('R'), 'A2');
    });

    test('refresh maps a 401 to UnauthorizedFailure', () async {
      final dio = MockDio();
      final req = RequestOptions(path: '/auth/refresh');
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenThrow(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 401, data: {'status': 'fail', 'data': 'Invalid Refresh Token'}),
      ));
      expect(() => DioAuthApi(dio).refresh('R'), throwsA(isA<UnauthorizedFailure>()));
    });
  });
}

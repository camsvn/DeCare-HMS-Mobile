import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

void main() {
  test('apiBaseUrl appends /api', () {
    expect(apiBaseUrl('http://decare.team'), 'http://decare.team/api');
  });

  test('buildDio sets base url, accept header and timeouts', () {
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => null);
    expect(dio.options.baseUrl, 'http://x/api');
    expect(dio.options.headers['Accept'], 'application/json');
    expect(dio.options.connectTimeout, jsonTimeout);
    expect(dio.options.receiveTimeout, jsonTimeout);
  });

  test('interceptor adds Bearer header only when a token exists', () async {
    String? token;
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => token);
    late RequestOptions seen;
    dio.httpClientAdapter = _CapturingAdapter((o) => seen = o);

    await dio.get('/a');
    expect(seen.headers.containsKey('Authorization'), isFalse);

    token = 'abc';
    await dio.get('/a');
    expect(seen.headers['Authorization'], 'Bearer abc');
  });

  group('401 refresh', () {
    test('401 then refresh then retry succeeds', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          return 'new';
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([
        (401, '{"status":"fail","data":"Invalid token"}'),
        (200, '{"status":"success","data":{"ok":true}}'),
      ]);
      dio.httpClientAdapter = adapter;

      final response = await dio.get<dynamic>('/a');
      expect(response.statusCode, 200);
      expect(adapter.authHeaders, ['Bearer old', 'Bearer new']);
      expect(refreshCalls, 1);
      expect(failures, 0);
    });

    test('refresh failure surfaces 401 and signals auth failure', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          return null;
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([(401, '{"status":"fail","data":"Invalid token"}')]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/a'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 1);
      expect(failures, 1);
      expect(adapter.authHeaders, ['Bearer old']);
    });

    test('a 401 on the retry propagates and signals auth failure once', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          return 'new';
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([
        (401, '{"status":"fail","data":"Invalid token"}'),
        (401, '{"status":"fail","data":"Invalid token"}'),
      ]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/a'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 1);
      expect(adapter.authHeaders, ['Bearer old', 'Bearer new']);
      // The retry re-enters onError, so the signal must not be sent twice.
      expect(failures, 1);
    });

    test('auth routes are not retried', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          return 'new';
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([(401, '{"status":"fail","data":"Invalid Refresh Token"}')]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.post<dynamic>('/auth/login', data: const {'username': 'u'}),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 0);
      expect(failures, 0);
      expect(adapter.authHeaders.length, 1);
    });

    test('a 401 from the refresh call itself does not stall the client', () async {
      // The real refresher posts /auth/refresh through this same client, so a
      // dead refresh token puts a second error through this interceptor while
      // the first one is still waiting for it. That must not deadlock.
      var refreshCalls = 0;
      var failures = 0;
      late final Dio dio;
      dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          try {
            await dio.post<dynamic>('/auth/refresh', data: const {'refreshToken': 'r'});
            return 'new';
          } catch (_) {
            return null;
          }
        },
        onAuthFailure: () => failures++,
      );
      dio.httpClientAdapter = _ScriptedAdapter([(401, '{"status":"fail","data":"Invalid token"}')]);

      await expectLater(
        dio.get<dynamic>('/a').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 1);
      expect(failures, 1);
    });

    test('parallel 401s share a single refresh', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          // Stays in flight long enough for the second 401 to reach the
          // interceptor, which is the case the de-duplication is for.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 'new';
        },
        onAuthFailure: () => failures++,
      );
      dio.httpClientAdapter = _TokenAdapter('Bearer new');

      final responses = await Future.wait([dio.get<dynamic>('/a'), dio.get<dynamic>('/b')])
          .timeout(const Duration(seconds: 2));

      expect(responses.map((r) => r.statusCode), [200, 200]);
      expect(refreshCalls, 1);
      expect(failures, 0);
    });

    test('a finalized multipart body is refreshed but not retried', () async {
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          return 'new';
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([
        (401, '{"status":"fail","data":"Invalid token"}'),
        (200, '{"status":"success","data":{"ok":true}}'),
      ]);
      dio.httpClientAdapter = adapter;

      final form = FormData.fromMap({'opid': '5'});
      await expectLater(
        dio.post<dynamic>('/tomogram', data: form),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      // The token was refreshed (so the next attempt has a live token) but the
      // consumed multipart stream cannot be replayed, so no retry happened.
      expect(refreshCalls, 1);
      expect(adapter.authHeaders.length, 1);
      // The session is fine, so no session-expiry signal.
      expect(failures, 0);
    });

    test('refresh that cannot reach the server surfaces the original 401 without signalling expiry', () async {
      // A dead network during the refresh is not a dead session: the original
      // 401 must reach the caller and the user must stay signed in.
      var refreshCalls = 0;
      var failures = 0;
      final dio = buildDio(
        baseUrl: 'http://x/api',
        tokenReader: () => 'old',
        refresher: () async {
          refreshCalls++;
          throw const CannotConnectFailure();
        },
        onAuthFailure: () => failures++,
      );
      final adapter = _ScriptedAdapter([(401, '{"status":"fail","data":"Invalid token"}')]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        dio.get<dynamic>('/a'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 1);
      expect(failures, 0);
      // No retry: the token was never renewed.
      expect(adapter.authHeaders, ['Bearer old']);

      // The single-flight future was cleared, so the next 401 tries again
      // instead of re-using the failed refresh forever.
      await expectLater(
        dio.get<dynamic>('/a'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      expect(refreshCalls, 2);
      expect(failures, 0);
    });
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onRequest);
  final void Function(RequestOptions) onRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    onRequest(options);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Answers 200 only to requests carrying [validAuth]; everything else is a 401.
class _TokenAdapter implements HttpClientAdapter {
  _TokenAdapter(this.validAuth);
  final String validAuth;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final ok = options.headers['Authorization'] == validAuth;
    return ResponseBody.fromString(
      ok ? '{"status":"success","data":{}}' : '{"status":"fail","data":"Invalid token"}',
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Answers each call with the next scripted `(status, body)` pair and records
/// the Authorization header each request actually carried. Dio re-uses the same
/// [RequestOptions] instance on a retry, so the header must be snapshotted here.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._script);
  final List<(int, String)> _script;
  final List<String?> authHeaders = [];
  int _calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    authHeaders.add(options.headers['Authorization'] as String?);
    final (status, body) = _script[_calls < _script.length ? _calls : _script.length - 1];
    _calls++;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

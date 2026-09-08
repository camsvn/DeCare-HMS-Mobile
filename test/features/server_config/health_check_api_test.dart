import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late DioHealthCheckApi api;

  Response<dynamic> response(dynamic data) => Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/healthcheck'),
        data: data,
      );

  setUp(() {
    dio = MockDio();
    when(() => dio.close(force: any(named: 'force'))).thenReturn(null);
    api = DioHealthCheckApi(dioFactory: (_) => dio);
  });

  test('completes on a success envelope carrying an uptime', () async {
    when(() => dio.get<dynamic>('/auth/healthcheck')).thenAnswer(
      (_) async => response({
        'status': 'success',
        'data': {'message': 'API is running!', 'uptime': 12},
      }),
    );
    await expectLater(api.check('http://decare.team'), completes);
    verify(() => dio.close(force: any(named: 'force'))).called(1);
  });

  test('success without an uptime is bad data', () async {
    when(() => dio.get<dynamic>('/auth/healthcheck')).thenAnswer(
      (_) async => response({
        'status': 'success',
        'data': {'message': 'API is running!'},
      }),
    );
    await expectLater(api.check('http://decare.team'), throwsA(isA<BadDataFailure>()));
  });

  test('a fail envelope is rejected with the server message', () async {
    when(() => dio.get<dynamic>('/auth/healthcheck'))
        .thenAnswer((_) async => response({'status': 'fail', 'data': 'nope'}));
    await expectLater(
      api.check('http://decare.team'),
      throwsA(isA<RejectedFailure>().having((e) => e.detail, 'detail', 'nope')),
    );
  });

  test('a connection error cannot connect', () async {
    when(() => dio.get<dynamic>('/auth/healthcheck')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/healthcheck'),
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(api.check('http://decare.team'), throwsA(isA<CannotConnectFailure>()));
  });
}

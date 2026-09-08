import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations_en.dart';
import 'package:hms_uploader/core/network/api_failure.dart';

final l10n = AppLocalizationsEn();

DioException _dio(DioExceptionType type, {int? status, dynamic data, Object? error}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    error: error,
    response: status == null ? null : Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('ApiFailure.from', () {
    test('passes through an existing ApiFailure', () {
      const f = TimeoutFailure();
      expect(ApiFailure.from(f), same(f));
    });
    test('maps timeouts', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(ApiFailure.from(_dio(t)), isA<TimeoutFailure>());
      }
    });
    test('maps connection errors', () {
      expect(ApiFailure.from(_dio(DioExceptionType.connectionError)), isA<CannotConnectFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badCertificate)), isA<CannotConnectFailure>());
      expect(
        ApiFailure.from(_dio(DioExceptionType.unknown, error: const SocketException('x'))),
        isA<CannotConnectFailure>(),
      );
    });
    test('maps unknown without socket error to bad data', () {
      expect(ApiFailure.from(_dio(DioExceptionType.unknown)), isA<BadDataFailure>());
    });
    test('maps status codes', () {
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 401)), isA<UnauthorizedFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 403)), isA<UnauthorizedFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 404)), isA<NotFoundFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 500)), isA<ServerFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 400)), isA<RejectedFailure>());
    });
    test('uses JSend messages from the body', () {
      final notFound = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 404, data: {'status': 'fail', 'data': 'Invalid OP Number'}));
      expect(notFound.detail, 'Invalid OP Number');
      expect(notFound.describe(l10n), 'Invalid OP Number');
      final server = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 500, data: {'status': 'error', 'message': 'Internal Server Error'}));
      expect(server.detail, 'Internal Server Error');
      final nested = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 400, data: {'status': 'fail', 'data': {'message': 'nested'}}));
      expect(nested.detail, 'nested');
    });
    test('falls back to localized default messages', () {
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 404)).describe(l10n), 'Not found');
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 503)).describe(l10n), 'Server error');
      expect(const CannotConnectFailure().describe(l10n), 'Could not reach the server');
      expect(const TimeoutFailure().describe(l10n), 'The server took too long to respond');
      expect(const UnauthorizedFailure().describe(l10n), 'Session expired');
      expect(const RejectedFailure().describe(l10n), 'Request rejected');
      expect(const BadDataFailure().describe(l10n), 'Unexpected response from server');
    });
    test('maps arbitrary errors to bad data', () {
      expect(ApiFailure.from(const FormatException('bad')), isA<BadDataFailure>());
    });
  });
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

/// All errors the data layer surfaces to the UI.
///
/// [detail] is the message the server supplied, if any. [describe] returns
/// that or a localized default, so screens never show raw error codes.
sealed class ApiFailure implements Exception {
  const ApiFailure([this.detail]);

  final String? detail;

  String describe(AppLocalizations l10n);

  /// Map any thrown object to an [ApiFailure]. Existing failures pass through.
  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) return _fromDio(error);
    return const BadDataFailure();
  }

  static ApiFailure _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const CannotConnectFailure();
      case DioExceptionType.cancel:
        return const RejectedFailure('Request cancelled');
      case DioExceptionType.unknown:
        return e.error is SocketException ? const CannotConnectFailure() : const BadDataFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final msg = serverMessage(e.response?.data);
        if (status == 401 || status == 403) return UnauthorizedFailure(msg);
        if (status == 404) return NotFoundFailure(msg);
        if (status >= 500) return ServerFailure(msg);
        return RejectedFailure(msg);
    }
  }

  @override
  String toString() => '$runtimeType(${detail ?? ''})';
}

/// Extract a message from a JSend body: `{status:'error', message}` or
/// `{status:'fail', data: <string | {message}>}`.
String? serverMessage(dynamic body) {
  if (body is! Map) return null;
  final message = body['message'];
  if (message is String && message.isNotEmpty) return message;
  final data = body['data'];
  if (data is String && data.isNotEmpty) return data;
  if (data is Map) {
    final nested = data['message'];
    if (nested is String && nested.isNotEmpty) return nested;
  }
  return null;
}

class CannotConnectFailure extends ApiFailure {
  const CannotConnectFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorCannotConnect;
}

class TimeoutFailure extends ApiFailure {
  const TimeoutFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorTimeout;
}

class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorUnauthorized;
}

class NotFoundFailure extends ApiFailure {
  const NotFoundFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorNotFound;
}

class ServerFailure extends ApiFailure {
  const ServerFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorServer;
}

class RejectedFailure extends ApiFailure {
  const RejectedFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorRejected;
}

class BadDataFailure extends ApiFailure {
  const BadDataFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorBadData;
}

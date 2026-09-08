import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/auth/data/session.dart';

abstract class AuthApi {
  Future<Session> login(String username, String password);
}

class DioAuthApi implements AuthApi {
  DioAuthApi(this._dio);

  final Dio _dio;

  @override
  Future<Session> login(String username, String password) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = unwrapEnvelope(response.data);
      if (data is! Map) throw const BadDataFailure();
      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      if (access is! String || refresh is! String) throw const BadDataFailure();
      return Session(accessToken: access, refreshToken: refresh);
    } catch (e) {
      final failure = ApiFailure.from(e);
      // The server answers 404 "Invalid Credentials" for a bad login.
      if (failure is NotFoundFailure || failure is UnauthorizedFailure) {
        throw const UnauthorizedFailure();
      }
      throw failure;
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) => DioAuthApi(ref.watch(dioProvider)));

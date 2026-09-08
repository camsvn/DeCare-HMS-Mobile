import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

abstract class HealthCheckApi {
  /// Throws an [ApiFailure] unless `GET <serverUrl>/api/auth/healthcheck`
  /// answers with a JSend success carrying an `uptime`.
  Future<void> check(String serverUrl);
}

class DioHealthCheckApi implements HealthCheckApi {
  DioHealthCheckApi({Dio Function(String baseUrl)? dioFactory})
      : _dioFactory = dioFactory ?? ((base) => buildDio(baseUrl: base, tokenReader: () => null));

  final Dio Function(String baseUrl) _dioFactory;

  @override
  Future<void> check(String serverUrl) async {
    final dio = _dioFactory(apiBaseUrl(serverUrl));
    try {
      final response = await dio.get<dynamic>('/auth/healthcheck');
      final data = unwrapEnvelope(response.data);
      if (data is! Map || data['uptime'] is! num) {
        throw const BadDataFailure();
      }
    } catch (e) {
      throw ApiFailure.from(e);
    } finally {
      dio.close();
    }
  }
}

final healthCheckApiProvider = Provider<HealthCheckApi>((ref) => DioHealthCheckApi());

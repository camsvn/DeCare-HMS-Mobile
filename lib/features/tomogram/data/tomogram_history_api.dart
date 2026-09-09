import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';

abstract class TomogramHistoryApi {
  Future<List<TomogramSet>> list(int opid);
}

/// `GET /tomogram?opid=N`: the patient's uploaded sets, newest first.
class DioTomogramHistoryApi implements TomogramHistoryApi {
  DioTomogramHistoryApi(this._dio);

  final Dio _dio;

  @override
  Future<List<TomogramSet>> list(int opid) async {
    try {
      final response = await _dio.get<dynamic>('/tomogram', queryParameters: {'opid': opid});
      final data = unwrapEnvelope(response.data);
      if (data is! List) return const [];
      return data.whereType<Map>().map(TomogramSet.fromJson).toList();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

final tomogramHistoryApiProvider =
    Provider<TomogramHistoryApi>((ref) => DioTomogramHistoryApi(ref.watch(dioProvider)));

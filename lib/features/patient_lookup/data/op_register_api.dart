import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

abstract class OpRegisterApi {
  Future<Patient> getByOpId(int opid);
}

class DioOpRegisterApi implements OpRegisterApi {
  DioOpRegisterApi(this._dio);

  final Dio _dio;

  @override
  Future<Patient> getByOpId(int opid) async {
    try {
      final response = await _dio.get<dynamic>('/opregister', queryParameters: {'opid': opid});
      final data = unwrapEnvelope(response.data);
      if (data is! Map) throw const BadDataFailure();
      return Patient.fromJson(data);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

final opRegisterApiProvider = Provider<OpRegisterApi>((ref) => DioOpRegisterApi(ref.watch(dioProvider)));

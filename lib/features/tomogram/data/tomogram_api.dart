import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:hms_uploader/features/tomogram/data/upload_result.dart';

abstract class TomogramApi {
  Future<List<UploadResult>> upload(int opid, List<TomogramDraft> drafts);
}

/// `POST /tomogram` multipart: `opid`, repeated `images`, `narrations[i]`.
class DioTomogramApi implements TomogramApi {
  DioTomogramApi(this._dio);

  final Dio _dio;

  @override
  Future<List<UploadResult>> upload(int opid, List<TomogramDraft> drafts) async {
    try {
      final form = FormData();
      form.fields.add(MapEntry('opid', opid.toString()));
      for (var i = 0; i < drafts.length; i++) {
        final d = drafts[i];
        form.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(
            d.filePath,
            filename: 'image${d.id}.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ));
        form.fields.add(MapEntry('narrations[$i]', d.description));
      }
      final response = await _dio.post<dynamic>(
        '/tomogram',
        data: form,
        options: Options(sendTimeout: uploadTimeout, receiveTimeout: uploadTimeout),
      );
      final data = unwrapEnvelope(response.data);
      if (data is! List) return const [];
      return data.whereType<Map>().map(UploadResult.fromJson).toList();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

final tomogramApiProvider = Provider<TomogramApi>((ref) => DioTomogramApi(ref.watch(dioProvider)));

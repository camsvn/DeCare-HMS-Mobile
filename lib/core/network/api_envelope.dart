import 'package:hms_uploader/core/network/api_failure.dart';

/// Unwrap a JSend response body. Returns the `data` payload on success and
/// throws an [ApiFailure] otherwise.
dynamic unwrapEnvelope(dynamic body) {
  if (body is! Map) throw const BadDataFailure();
  if (body['status'] == 'success') return body['data'];
  throw RejectedFailure(serverMessage(body));
}

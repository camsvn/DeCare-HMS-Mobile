import 'package:hms_uploader/core/utils/jwt.dart';

class Session {
  const Session({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// The React Native app treated a session as restorable while the refresh
  /// token's `exp` was in the future. Same rule here.
  bool isValid({DateTime? now}) => isJwtValid(refreshToken, now: now);
}

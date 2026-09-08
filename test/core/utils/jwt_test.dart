import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/jwt.dart';

String _token(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.sig';
}

void main() {
  test('decodes exp', () {
    final exp = DateTime.utc(2030, 1, 1);
    final t = _token({'exp': exp.millisecondsSinceEpoch ~/ 1000});
    expect(jwtExpiry(t), exp);
  });
  test('returns null for malformed token', () {
    expect(jwtExpiry('abc'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
    expect(jwtExpiry(_token({'foo': 1})), isNull);
  });
  test('isJwtValid compares against now', () {
    final now = DateTime.utc(2026, 9, 8);
    final live = _token({'exp': now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000});
    final dead = _token({'exp': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000});
    expect(isJwtValid(live, now: now), isTrue);
    expect(isJwtValid(dead, now: now), isFalse);
    expect(isJwtValid(null, now: now), isFalse);
    expect(isJwtValid('garbage', now: now), isFalse);
  });
}

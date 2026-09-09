import 'dart:convert';

/// Decode the `exp` claim of a JWT without verifying its signature.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload);
    if (map is! Map) return null;
    final exp = map['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } on FormatException {
    return null;
  }
}

bool isJwtValid(String? token, {DateTime? now}) {
  if (token == null || token.isEmpty) return false;
  final exp = jwtExpiry(token);
  if (exp == null) return false;
  return exp.isAfter(now ?? DateTime.now().toUtc());
}

/// Read a claim from the JWT payload as a string, or null.
String? jwtClaim(String token, String claim) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final map = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (map is! Map) return null;
    final value = map[claim];
    return value?.toString();
  } on FormatException {
    return null;
  }
}

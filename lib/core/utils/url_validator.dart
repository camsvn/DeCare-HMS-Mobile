final RegExp _serverUrlPattern = RegExp(
  r'^(https?:\/\/)?((localhost|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d{1,5})?|(www\.)?[\w\-]+(\.[\w\-]+)*\.[a-z]{2,}(:\d{1,5})?|([A-Za-z0-9_-]+\.?[A-Za-z0-9_-]*:[0-9]+))(\/\S*)?$',
  caseSensitive: false,
);

bool isValidServerUrl(String input) {
  final s = input.trim();
  if (s.isEmpty) return false;
  return _serverUrlPattern.hasMatch(s);
}

/// Returns a usable base URL (scheme present, no trailing slash) or null.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (!isValidServerUrl(s)) return null;
  final lower = s.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    s = 'http://$s';
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

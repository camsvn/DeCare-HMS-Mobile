import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many recent labels are kept. Enough to cover a clinic's usual parts
/// without turning the suggestion row into a list to read.
const int recentLabelsCap = 10;

/// The descriptions this device has used before, newest first.
///
/// They are typed once and reused for weeks — "Left forearm", "Scalp" — so
/// they are worth keeping across launches, and a plain string list is all the
/// storage that needs.
class RecentLabelsRepository {
  RecentLabelsRepository(this._prefs);

  static const key = 'recent_labels';

  final SharedPreferences _prefs;

  /// The stored labels, minus anything too long to offer.
  ///
  /// Filtered on the way out as well as on the way in, so a device that
  /// remembered a sentence before the cap existed stops offering it without
  /// needing a migration.
  List<String> read() => [
        for (final label in _prefs.getStringList(key) ?? const <String>[])
          // Measured on the trimmed text, as `remember` measures it, so the
          // two cannot disagree about what is too long.
          if (label.trim().length <= suggestionMaxLength) label,
      ];

  /// Stops offering [label] on this device, matched the way the list dedupes:
  /// case-insensitively, on the trimmed text.
  Future<void> forget(String label) async {
    final target = label.trim().toLowerCase();
    await _prefs.setStringList(
      key,
      [
        for (final stored in read())
          if (stored.trim().toLowerCase() != target) stored,
      ],
    );
  }

  /// Puts [labels] in front of what is already there, keeping the order they
  /// were given: the first one is the most recent. Blanks are dropped, and a
  /// label already remembered in another case keeps its newest spelling
  /// rather than showing up twice.
  Future<void> remember(Iterable<String> labels) =>
      _prefs.setStringList(key, _merged(labels));

  List<String> _merged(Iterable<String> labels) {
    final out = <String>[];
    final seen = <String>{};
    for (final label in [...labels, ...read()]) {
      final text = label.trim();
      if (text.isEmpty || text.length > suggestionMaxLength) continue;
      if (!seen.add(text.toLowerCase())) continue;
      out.add(text);
      if (out.length == recentLabelsCap) break;
    }
    return out;
  }
}

final recentLabelsRepositoryProvider = Provider<RecentLabelsRepository>(
  (ref) => RecentLabelsRepository(ref.watch(sharedPreferencesProvider)),
);

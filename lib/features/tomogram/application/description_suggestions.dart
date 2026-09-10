import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_history_controller.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';

/// [history] first, then the labels from [recent] it does not already carry.
///
/// This patient's own uploaded narrations are the best guess at what the next
/// photo of them is called, so they lead; the device's recent labels fill the
/// rest of the row. Both lists arrive newest first and stay in that order.
/// Trimmed, blanks dropped, deduped case-insensitively keeping the first (so
/// the newest) spelling, and cut off at [max].
List<String> mergeSuggestions(List<String> history, List<String> recent, {int max = 8}) {
  final out = <String>[];
  final seen = <String>{};
  for (final candidate in [...history, ...recent]) {
    final text = candidate.trim();
    if (text.isEmpty || !seen.add(text.toLowerCase())) continue;
    out.add(text);
    if (out.length == max) break;
  }
  return out;
}

/// What to offer as a description for one patient's next photo.
///
/// The history is read as it comes: the API returns the sets newest first, and
/// re-sorting here would put an older set's narration in front. A history
/// still loading, or one that failed, simply contributes nothing — the recent
/// labels alone are still worth offering.
final descriptionSuggestionsProvider = Provider.autoDispose.family<List<String>, int>((ref, opid) {
  final sets = ref.watch(tomogramHistoryProvider(opid)).valueOrNull ?? const <TomogramSet>[];
  final history = [for (final set in sets) for (final detail in set.details) detail.narration];
  return mergeSuggestions(history, ref.watch(recentLabelsProvider));
});

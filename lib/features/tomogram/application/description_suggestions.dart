import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_history_controller.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';

/// The longest a description may be and still be worth offering as a chip.
///
/// A narration can run to 200 characters, and some of what comes back from the
/// history is a sentence or a paste of somebody's notes. As a chip it would
/// wrap over two lines and push the rest of the row off the screen, and as a
/// suggestion it is not a body site anyone would pick — so it is dropped
/// rather than truncated, which would offer text that is not what it says.
const int suggestionMaxLength = 40;

/// [history] first, then the labels from [recent] it does not already carry.
///
/// This patient's own uploaded narrations are the best guess at what the next
/// photo of them is called, so they lead; the device's recent labels fill the
/// rest of the row. Both lists arrive newest first and stay in that order.
/// Trimmed, blanks and anything past [suggestionMaxLength] dropped, deduped
/// case-insensitively keeping the first (so the newest) spelling, and cut off
/// at [max].
List<String> mergeSuggestions(List<String> history, List<String> recent, {int max = 8}) {
  final out = <String>[];
  final seen = <String>{};
  for (final candidate in [...history, ...recent]) {
    final text = candidate.trim();
    if (text.isEmpty || text.length > suggestionMaxLength) continue;
    if (!seen.add(text.toLowerCase())) continue;
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
  final sets = ref.watch(tomogramHistoryProvider(opid)).value ?? const <TomogramSet>[];
  final history = [for (final set in sets) for (final detail in set.details) detail.narration];
  return mergeSuggestions(history, ref.watch(recentLabelsProvider));
});

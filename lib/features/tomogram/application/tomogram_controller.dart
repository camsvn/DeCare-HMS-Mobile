import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_history_controller.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_api.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:uuid/uuid.dart';

final uuidProvider = Provider<String Function()>((ref) => const Uuid().v4);

class TomogramState {
  const TomogramState({this.drafts = const [], this.uploading = false});

  final List<TomogramDraft> drafts;
  final bool uploading;

  TomogramState copyWith({List<TomogramDraft>? drafts, bool? uploading}) =>
      TomogramState(drafts: drafts ?? this.drafts, uploading: uploading ?? this.uploading);
}

/// Per-patient draft list, keyed by OP number. Lives only while the tomogram
/// screen is mounted; leftover files are deleted on dispose.
class TomogramController extends AutoDisposeFamilyNotifier<TomogramState, int> {
  @override
  TomogramState build(int arg) {
    ref.onDispose(() {
      final paths = state.drafts.map((d) => d.filePath).toList();
      if (paths.isNotEmpty) deleteFiles(paths);
    });
    return const TomogramState();
  }

  /// Appends [items] as drafts, keeping their order and the description each
  /// arrived with — the label the photo was taken under, on the capture path.
  void addDrafts(Iterable<({String path, String description})> items) {
    final newId = ref.read(uuidProvider);
    state = state.copyWith(drafts: [
      ...state.drafts,
      for (final item in items)
        TomogramDraft(id: newId(), filePath: item.path, description: item.description),
    ]);
  }

  /// Appends [paths] with no description, which is all a gallery pick knows.
  void addFiles(List<String> paths) =>
      addDrafts([for (final p in paths) (path: p, description: '')]);

  /// The drafts as they will be sent: descriptions trimmed, and a blank one
  /// inheriting the previous photo's effective description — a burst of one
  /// site is shot under a single label, and typing it again per card is the
  /// part staff skip. The first photo has no previous, so blank stays blank.
  /// Ids and paths are untouched, and [state] keeps the raw text the user is
  /// still typing in; the card shows the inherited text as its placeholder
  /// instead.
  List<TomogramDraft> get resolvedDrafts {
    final resolved = <TomogramDraft>[];
    var previous = '';
    for (final d in state.drafts) {
      final trimmed = d.description.trim();
      final effective = trimmed.isEmpty ? previous : trimmed;
      resolved.add(effective == d.description ? d : d.copyWith(description: effective));
      previous = effective;
    }
    return resolved;
  }

  Future<void> remove(String id) async {
    final target = state.drafts.where((d) => d.id == id).toList();
    state = state.copyWith(drafts: state.drafts.where((d) => d.id != id).toList());
    await deleteFiles(target.map((d) => d.filePath));
  }

  void updateDescription(String id, String text) {
    state = state.copyWith(
      drafts: [for (final d in state.drafts) d.id == id ? d.copyWith(description: text) : d],
    );
  }

  Future<void> clearAll() async {
    final paths = state.drafts.map((d) => d.filePath).toList();
    state = state.copyWith(drafts: const []);
    await deleteFiles(paths);
  }

  /// Uploads all drafts. On success drafts are cleared and files deleted.
  /// Throws [ApiFailure] on failure, leaving drafts intact for a retry.
  Future<void> upload() async {
    // What the server is sent, and so what "recent labels" learns from: the
    // inherited descriptions, not the blanks on screen.
    final drafts = resolvedDrafts;
    if (drafts.isEmpty) return;
    state = state.copyWith(uploading: true);
    try {
      await ref.read(tomogramApiProvider).upload(arg, drafts);
    } catch (e) {
      state = state.copyWith(uploading: false);
      throw ApiFailure.from(e);
    }
    state = const TomogramState();
    // The patient now has one more uploaded set; drop the cached history so the
    // screen's history card reflects the upload.
    ref.invalidate(tomogramHistoryProvider(arg));
    await deleteFiles(drafts.map((d) => d.filePath));
    // Last, and best-effort: these descriptions lead the suggestions on the
    // next patient (the repository trims, drops the blanks and dedupes), but a
    // device that cannot write its prefs must not turn a finished upload into a
    // failure the user is asked to retry.
    try {
      await ref.read(recentLabelsProvider.notifier).remember(drafts.map((d) => d.description));
    } catch (_) {}
  }
}

final tomogramControllerProvider =
    NotifierProvider.autoDispose.family<TomogramController, TomogramState, int>(TomogramController.new);

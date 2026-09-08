import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
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

  void addFiles(List<String> paths) {
    final newId = ref.read(uuidProvider);
    state = state.copyWith(drafts: [
      ...state.drafts,
      for (final p in paths) TomogramDraft(id: newId(), filePath: p),
    ]);
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
    final drafts = state.drafts;
    if (drafts.isEmpty) return;
    state = state.copyWith(uploading: true);
    try {
      await ref.read(tomogramApiProvider).upload(arg, drafts);
    } catch (e) {
      state = state.copyWith(uploading: false);
      throw ApiFailure.from(e);
    }
    state = const TomogramState();
    await deleteFiles(drafts.map((d) => d.filePath));
  }
}

final tomogramControllerProvider =
    NotifierProvider.autoDispose.family<TomogramController, TomogramState, int>(TomogramController.new);

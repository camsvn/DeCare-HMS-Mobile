import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/tomogram/application/connectivity_provider.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_history_controller.dart';
import 'package:hms_uploader/features/tomogram/data/pending_upload.dart';
import 'package:hms_uploader/features/tomogram/data/pending_uploads_repository.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_api.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';

/// Uploads that could not reach the server, retried in the background.
///
/// Lives for the whole app run (not auto-disposed): the queue must keep
/// draining while the user is somewhere else entirely.
class UploadQueueController extends AsyncNotifier<List<PendingUpload>> {
  bool _running = false;
  StreamSubscription<bool>? _sub;

  /// Assume online, so the first event the plugin delivers on subscribe is not
  /// mistaken for a reconnection.
  bool _lastOnline = true;

  /// True while a run is in flight. Every state update during a run carries the
  /// loading flag, so widgets rebuild and see this change.
  bool get isProcessing => _running;

  @override
  Future<List<PendingUpload>> build() async => ref.watch(pendingUploadsRepositoryProvider).read();

  /// Subscribes to connectivity and drains whatever the last run left behind.
  /// Called once at app start.
  Future<void> start() async {
    _sub?.cancel();
    _sub = ref.read(connectivityServiceProvider).onlineChanges.listen((online) {
      final cameBack = online && !_lastOnline;
      _lastOnline = online;
      if (cameBack) unawaited(processQueue());
    });
    ref.onDispose(() => _sub?.cancel());
    // The persisted list has to be in [state] before a run can act on it.
    await future;
    await processQueue();
  }

  /// Takes over a failed upload's drafts: copies the files somewhere durable,
  /// persists the entry, and tries it at once when there is a network.
  Future<void> enqueue(int opid, String patientName, List<TomogramDraft> drafts) async {
    final repo = ref.read(pendingUploadsRepositoryProvider);
    final staged = await repo.stage(PendingUpload(
      id: ref.read(uuidProvider)(),
      opid: opid,
      patientName: patientName,
      files: [for (final d in drafts) PendingFile(path: d.filePath, description: d.description)],
      createdAt: DateTime.now(),
    ));
    final next = [..._entries, staged];
    await repo.write(next);
    _publish(next);
    if (await ref.read(connectivityServiceProvider).isOnline()) unawaited(processQueue());
  }

  /// Uploads the entries oldest first. A network failure ends the run and waits
  /// for the next trigger; any other failure counts an attempt against that
  /// entry and the run moves on. Only one run at a time.
  Future<void> processQueue() async {
    if (_running) return;
    final queued = _entries;
    if (queued.isEmpty) return;
    _running = true;
    _publish(queued);
    try {
      for (final entry in queued) {
        if (entry.isFailed) continue;
        // An enqueue or a discard may have landed while this run was awaiting.
        if (!_entries.any((e) => e.id == entry.id)) continue;
        try {
          await ref.read(tomogramApiProvider).upload(entry.opid, [
            for (var i = 0; i < entry.files.length; i++)
              // The id only names the multipart part, so the index is enough
              // to keep the filenames unique within one request.
              TomogramDraft(id: 'q$i', filePath: entry.files[i].path, description: entry.files[i].description),
          ]);
          await ref.read(pendingUploadsRepositoryProvider).purge(entry);
          await _replace(entry.id, null);
          // The patient has one more uploaded set now.
          ref.invalidate(tomogramHistoryProvider(entry.opid));
        } on ApiFailure catch (e) {
          if (e is CannotConnectFailure || e is TimeoutFailure) break;
          await _replace(
            entry.id,
            entry.copyWith(attempts: entry.attempts + 1, lastError: e.detail ?? e.runtimeType.toString()),
          );
        }
      }
    } finally {
      _running = false;
      _publish(_entries);
    }
  }

  /// Clears the failure counters so exhausted entries move again, then runs.
  Future<void> retryAll() async {
    final next = [for (final e in _entries) e.copyWith(attempts: 0, clearLastError: true)];
    await ref.read(pendingUploadsRepositoryProvider).write(next);
    _publish(next);
    await processQueue();
  }

  /// Drops one entry and its photos for good.
  Future<void> discard(String id) async {
    final target = _entries.where((e) => e.id == id).toList();
    if (target.isEmpty) return;
    await ref.read(pendingUploadsRepositoryProvider).purge(target.single);
    await _replace(id, null);
  }

  List<PendingUpload> get _entries => state.valueOrNull ?? const [];

  /// Swaps one entry for [replacement], or removes it when that is null, and
  /// persists the result.
  Future<void> _replace(String id, PendingUpload? replacement) async {
    final next = <PendingUpload>[];
    for (final e in _entries) {
      if (e.id != id) {
        next.add(e);
      } else if (replacement != null) {
        next.add(replacement);
      }
    }
    await ref.read(pendingUploadsRepositoryProvider).write(next);
    _publish(next);
  }

  void _publish(List<PendingUpload> entries) {
    final data = AsyncData(entries);
    state = _running ? const AsyncLoading<List<PendingUpload>>().copyWithPrevious(data) : data;
  }
}

final uploadQueueProvider =
    AsyncNotifierProvider<UploadQueueController, List<PendingUpload>>(UploadQueueController.new);

/// How many uploads are waiting, for the dashboard's pending chip.
final pendingCountProvider = Provider<int>((ref) => ref.watch(uploadQueueProvider).valueOrNull?.length ?? 0);

/// The queued entry for one OP number, if there is one.
final pendingForOpidProvider = Provider.family<PendingUpload?, int>((ref, opid) {
  final entries = ref.watch(uploadQueueProvider).valueOrNull ?? const <PendingUpload>[];
  for (final entry in entries) {
    if (entry.opid == opid) return entry;
  }
  return null;
});

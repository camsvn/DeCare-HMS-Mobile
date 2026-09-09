import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
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
  ProviderSubscription<String?>? _tokenSub;

  /// Set when a trigger arrives while a run is in flight, so the run repeats
  /// instead of dropping it.
  bool _rerunRequested = false;

  /// Whether this run has already spent its one post-refresh retry. A 401
  /// usually means the interceptor has just renewed the token, so one more
  /// pass is worth it — but only one, so a genuinely dead session cannot spin
  /// the queue against the server.
  bool _authRetryUsed = false;

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
      // Every event that reports a network is a trigger, not just one that
      // follows a reported loss. Tracking the previous state would strand the
      // queue after an offline launch, where the plugin reports the working
      // network without ever having reported the missing one. Running again is
      // free: [processQueue] collapses to nothing when a run is already in
      // flight or the queue is empty.
      if (online) unawaited(processQueue());
    });
    // Signing in is a trigger too: a queue that was held back while the user
    // was signed out can go now, without waiting for a connectivity event.
    _tokenSub?.close();
    _tokenSub = ref.listen<String?>(accessTokenProvider, (prev, next) {
      if (prev == null && next != null) unawaited(processQueue());
    });
    ref.onDispose(() {
      _sub?.cancel();
      _tokenSub?.close();
    });
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

  /// Uploads the entries oldest first. A network failure or a 401 ends the pass
  /// and waits for the next trigger; any other failure counts an attempt
  /// against that entry and the pass moves on. Only one run at a time — a
  /// trigger that arrives mid-run earns one more pass rather than being
  /// dropped, since the entry it is about may have been enqueued after this run
  /// started.
  ///
  /// Does nothing at all while the user is signed out: every request would come
  /// back 401, and burning the attempt ceiling on requests that cannot succeed
  /// would leave the queue failed for no reason.
  Future<void> processQueue() async {
    if (ref.read(accessTokenProvider) == null) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    if (_entries.isEmpty) return;
    _running = true;
    _authRetryUsed = false;
    _publish(_entries);
    try {
      do {
        _rerunRequested = false;
        await _pass();
      } while (_rerunRequested && _entries.isNotEmpty);
    } finally {
      _running = false;
      _rerunRequested = false;
      _publish(_entries);
    }
  }

  /// One walk over the queue as it stands at the start of the walk.
  Future<void> _pass() async {
    for (final entry in _entries) {
      if (entry.isFailed) continue;
      // An enqueue or a discard may have landed while this pass was awaiting.
      if (!_entries.any((e) => e.id == entry.id)) continue;
      // The staged photos are gone — an OS cleanup of the documents folder, or
      // a purge that only half ran. There is nothing left to send, so drop the
      // entry instead of failing it against the server forever.
      if (entry.files.any((f) => !File(f.path).existsSync())) {
        await ref.read(pendingUploadsRepositoryProvider).purge(entry);
        await _replace(entry.id, null);
        continue;
      }
      try {
        await ref.read(tomogramApiProvider).upload(entry.opid, [
          for (var i = 0; i < entry.files.length; i++)
            // The id only names the multipart part, so the index is enough
            // to keep the filenames unique within one request.
            TomogramDraft(id: 'q$i', filePath: entry.files[i].path, description: entry.files[i].description),
        ]);
        // Persist the removal before deleting the photos: a crash in between
        // then leaves an orphan folder, not an entry pointing at files that
        // are already gone.
        await _replace(entry.id, null);
        await ref.read(pendingUploadsRepositoryProvider).purge(entry);
        // The patient has one more uploaded set now.
        ref.invalidate(tomogramHistoryProvider(entry.opid));
      } catch (e) {
        // Not just [ApiFailure]: `dioProvider` throws a [StateError] when no
        // server is configured, and `start()` is unawaited, so anything that
        // escaped here would land in the zone's error handler instead.
        final failure = ApiFailure.from(e);
        if (failure is CannotConnectFailure || failure is TimeoutFailure) return;
        if (failure is UnauthorizedFailure) {
          // Not this entry's fault: the token was stale, and the interceptor
          // has just renewed it. End the pass without counting an attempt and
          // ask for one more pass with the fresh token.
          if (!_authRetryUsed) {
            _authRetryUsed = true;
            _rerunRequested = true;
          }
          return;
        }
        await _replace(
          entry.id,
          entry.copyWith(
            attempts: entry.attempts + 1,
            lastError: failure.detail ?? failure.runtimeType.toString(),
          ),
        );
      }
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

/// How many photos are waiting for one OP number, across every entry it has —
/// two failed uploads for the same patient are one waiting count to the user.
final pendingFileCountForOpidProvider = Provider.family<int, int>((ref, opid) {
  final entries = ref.watch(uploadQueueProvider).valueOrNull ?? const <PendingUpload>[];
  var count = 0;
  for (final entry in entries) {
    if (entry.opid == opid) count += entry.files.length;
  }
  return count;
});

/// The queued entry for one OP number, if there is one.
final pendingForOpidProvider = Provider.family<PendingUpload?, int>((ref, opid) {
  final entries = ref.watch(uploadQueueProvider).valueOrNull ?? const <PendingUpload>[];
  for (final entry in entries) {
    if (entry.opid == opid) return entry;
  }
  return null;
});

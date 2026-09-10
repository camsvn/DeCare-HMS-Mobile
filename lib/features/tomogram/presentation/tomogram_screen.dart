import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/application/upload_queue_controller.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';
import 'package:hms_uploader/features/tomogram/presentation/draft_preview_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/add_source_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/pending_line.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_card.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_history_card.dart';
import 'package:permission_handler/permission_handler.dart';

class TomogramScreen extends ConsumerStatefulWidget {
  const TomogramScreen({super.key, required this.patient, this.onPermissionsDenied, this.onCapture});

  final Patient patient;

  /// Defaults to pushing the permission screen. Injectable for tests.
  final void Function(List<Permission> denied)? onPermissionsDenied;

  /// Defaults to pushing the in-app capture screen, which pops the shots it
  /// took (or null when the user discarded them). Injectable for tests.
  final Future<List<Shot>?> Function(BuildContext context)? onCapture;

  @override
  ConsumerState<TomogramScreen> createState() => _TomogramScreenState();
}

/// Bottom padding under the draft list: `DsSpace.x8` plus the 52 dp FAB and its
/// 4 dp of breathing room.
const double _fabClearance = DsSpace.x8 + 56;

class _TomogramScreenState extends ConsumerState<TomogramScreen> {
  int get _opid => widget.patient.opid;

  /// Opens the draft at [index] full screen, the way the capture screen opens
  /// a shot: a fade, because it is the same photo the card was showing.
  void _openDraft(int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: DsMotion.of(context, DsMotion.base),
        reverseTransitionDuration: DsMotion.of(context, DsMotion.base),
        pageBuilder: (_, __, ___) => DraftPreviewScreen(opid: _opid, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  Future<void> _add() async {
    final source = await showAddSourceSheet(context);
    if (source == null || !mounted) return;
    final picker = ref.read(mediaPickerServiceProvider);
    final denied = await picker.deniedPermissions(source);
    if (!mounted) return;
    if (denied.isNotEmpty) {
      (widget.onPermissionsDenied ?? _pushPermission)(denied);
      return;
    }
    if (source == MediaSource.camera) {
      await _capture();
      return;
    }
    final result = await picker.pickFromGallery();
    if (!mounted) return;
    ref.read(tomogramControllerProvider(_opid).notifier).addFiles(result.accepted);
    final l10n = context.l10n;
    if (result.overLimit > 0) {
      showDsBanner(context, l10n.tomogramPickLimit(galleryPickLimit), kind: DsBannerKind.warning);
    }
    if (result.rejected > 0) {
      showDsBanner(context, l10n.tomogramOnlyJpeg, kind: DsBannerKind.warning);
    }
  }

  /// Hands off to the capture screen, which takes a burst of photos and pops
  /// them. A null result means the user discarded the lot.
  Future<void> _capture() async {
    final shots = await (widget.onCapture ?? _pushCapture)(context);
    if (shots == null) return;
    final paths = [for (final shot in shots) shot.path];
    if (!mounted) {
      // This screen left while the capture screen was up (a route change, a
      // deep link): nothing is left to own these files, so they would sit in
      // the cache until the OS reclaimed it.
      await deleteFiles(paths);
      return;
    }
    // The label each shot was taken under becomes its description, so a
    // labelled burst needs no typing here at all.
    ref
        .read(tomogramControllerProvider(_opid).notifier)
        .addDrafts([for (final shot in shots) (path: shot.path, description: shot.label)]);
  }

  Future<List<Shot>?> _pushCapture(BuildContext context) =>
      context.push<List<Shot>>(RoutePaths.capture(_opid));

  void _pushPermission(List<Permission> denied) => context.push(RoutePaths.permission, extra: denied);

  /// Leaves the screen once there is nothing left to confirm.
  ///
  /// Not `maybePop`: the enclosing [PopScope] still reports the pre-clear
  /// `canPop` until the next build, so asking the route again would bounce
  /// straight back into [_back] through `onPopInvoked` — an endless loop.
  void _pop() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _upload() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final notifier = ref.read(tomogramControllerProvider(_opid).notifier);
    // Read before the first await: this screen can be gone by the time the
    // queue has staged its files, and `ref` cannot be used after that.
    final labels = ref.read(recentLabelsProvider.notifier);
    try {
      await notifier.upload();
      if (!mounted) return;
      showDsBanner(context, l10n.tomogramUploaded, kind: DsBannerKind.success);
      _pop();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      // Unreachable server: hand the photos to the offline queue rather than
      // asking the user to sit on the screen until the network comes back.
      // Anything the server actively refused is the user's to fix, so those
      // drafts stay put.
      if (e is CannotConnectFailure || e is TimeoutFailure) {
        // The queue stores a description per file, so it takes the inherited
        // ones the upload would have sent rather than the blanks on screen.
        final resolved = notifier.resolvedDrafts;
        try {
          await ref.read(uploadQueueProvider.notifier).enqueue(_opid, widget.patient.name, resolved);
        } catch (_) {
          // The photos could not even be copied aside (an evicted picker cache,
          // a full disk). Report the upload failure and keep the drafts, which
          // is the best the user can act on.
          if (!mounted) return;
          showDsBanner(context, l10n.tomogramUploadError(e.describe(l10n)), kind: DsBannerKind.danger);
          return;
        }
        // The queue owns its own copies now, so this only drops the originals.
        await notifier.clearAll();
        if (mounted) {
          showDsBanner(context, l10n.tomogramQueued, kind: DsBannerKind.warning);
          _pop();
        }
        // Last, and best-effort: queued counts as used, so these descriptions
        // lead the suggestions on the next patient without waiting for the
        // queue to drain — but the photos are safe either way, and a prefs
        // failure must not read as a failed queueing. Runs unmounted too: the
        // labels notifier was read up front for exactly that.
        try {
          await labels.remember(resolved.map((d) => d.description));
        } catch (_) {}
        return;
      }
      showDsBanner(context, l10n.tomogramUploadError(e.describe(l10n)), kind: DsBannerKind.danger);
    }
  }

  /// Back arrow and system back: drafts are unsaved work, so confirm first.
  Future<void> _back() async {
    final notifier = ref.read(tomogramControllerProvider(_opid).notifier);
    if (ref.read(tomogramControllerProvider(_opid)).drafts.isEmpty) {
      _pop();
      return;
    }
    final l10n = context.l10n;
    final discard = await showDsDialog(
      context,
      title: l10n.tomogramDiscardTitle,
      body: l10n.tomogramDiscardBody,
      confirmLabel: l10n.commonDiscard,
      destructive: true,
    );
    if (!discard || !mounted) return;
    await notifier.clearAll();
    if (mounted) _pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tomogramControllerProvider(_opid));
    final notifier = ref.read(tomogramControllerProvider(_opid).notifier);
    final drafts = state.drafts;
    final suggestions = ref.watch(descriptionSuggestionsProvider(_opid));

    return PopScope(
      canPop: drafts.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: DsAppBar(
          title: widget.patient.name,
          titleTrailing: DsChip(text: '$_opid', mono: true, onShell: true),
          onBack: _back,
          actions: [
            if (drafts.isNotEmpty)
              DsButton.ghost(label: l10n.tomogramUpload, onPressed: state.uploading ? null : _upload),
          ],
        ),
        floatingActionButton: DsFab(
          icon: Icons.add,
          tooltip: l10n.tomogramAddPhoto,
          onPressed: state.uploading ? null : _add,
        ),
        body: Column(
          children: [
            if (state.uploading) const DsProgressBar(),
            // Both collapse to nothing: no queued upload, no history yet.
            if (_opid > 0) ...[
              PendingLine(opid: _opid),
              TomogramHistoryCard(opid: _opid),
            ],
            Expanded(
              child: drafts.isEmpty
                  ? DsEmptyState(
                      illustration: SvgPicture.asset('assets/images/add_tomogram.svg'),
                      heading: l10n.tomogramEmptyTitle,
                      body: l10n.tomogramEmptyBody,
                    )
                  : ListView.separated(
                      // Bottom gap clears the 52 dp FAB plus its 16 dp margin,
                      // so the last card's description field stays reachable.
                      padding: const EdgeInsets.fromLTRB(
                          DsSpace.gutter, DsSpace.x3, DsSpace.gutter, _fabClearance),
                      itemCount: drafts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: DsSpace.x3),
                      itemBuilder: (_, i) => TomogramCard(
                        key: ValueKey(drafts[i].id),
                        draft: drafts[i],
                        index: i,
                        total: drafts.length,
                        onDelete: () => notifier.remove(drafts[i].id),
                        onDescriptionChanged: (text) => notifier.updateDescription(drafts[i].id, text),
                        onTapImage: () => _openDraft(i),
                        // Inherit-forward lives in the controller; the card
                        // only displays what it resolved, so what is shown and
                        // what is uploaded cannot drift apart.
                        inheritedDescription: notifier.inheritedDescriptionFor(i),
                        suggestions: suggestions,
                        onSuggestion: (text) => notifier.updateDescription(drafts[i].id, text),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/add_source_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_card.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_history_card.dart';
import 'package:permission_handler/permission_handler.dart';

class TomogramScreen extends ConsumerStatefulWidget {
  const TomogramScreen({super.key, required this.patient, this.onPermissionsDenied});

  final Patient patient;

  /// Defaults to pushing the permission screen. Injectable for tests.
  final void Function(List<Permission> denied)? onPermissionsDenied;

  @override
  ConsumerState<TomogramScreen> createState() => _TomogramScreenState();
}

/// Bottom padding under the draft list: `DsSpace.x8` plus the 52 dp FAB and its
/// 4 dp of breathing room.
const double _fabClearance = DsSpace.x8 + 56;

class _TomogramScreenState extends ConsumerState<TomogramScreen> {
  int get _opid => widget.patient.opid;

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
    final result = await picker.pick(source);
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
    try {
      await ref.read(tomogramControllerProvider(_opid).notifier).upload();
      if (!mounted) return;
      showDsBanner(context, l10n.tomogramUploaded, kind: DsBannerKind.success);
      _pop();
    } on ApiFailure catch (e) {
      if (!mounted) return;
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
            // Collapses to nothing when the patient has no uploads yet.
            if (_opid > 0) TomogramHistoryCard(opid: _opid),
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
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

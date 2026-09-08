import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/widgets/loader_modal.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/add_source_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/patient_bar.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_card.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_empty_state.dart';
import 'package:permission_handler/permission_handler.dart';

class TomogramScreen extends ConsumerStatefulWidget {
  const TomogramScreen({super.key, required this.patient, this.onPermissionsDenied});

  final Patient patient;

  /// Defaults to pushing the permission screen. Injectable for tests.
  final void Function(List<Permission> denied)? onPermissionsDenied;

  @override
  ConsumerState<TomogramScreen> createState() => _TomogramScreenState();
}

class _TomogramScreenState extends ConsumerState<TomogramScreen> {
  int get _opid => widget.patient.opid;
  late final _opController = TextEditingController(text: _opid.toString());

  @override
  void dispose() {
    _opController.dispose();
    super.dispose();
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
    final result = await picker.pick(source);
    if (!mounted) return;
    ref.read(tomogramControllerProvider(_opid).notifier).addFiles(result.accepted);
    final l10n = context.l10n;
    if (result.overLimit > 0) {
      showFlash(context, l10n.tomogramPickLimit(galleryPickLimit), type: FlashType.warning);
    }
    if (result.rejected > 0) {
      showFlash(context, l10n.tomogramOnlyJpeg, type: FlashType.warning);
    }
  }

  void _pushPermission(List<Permission> denied) => context.push(RoutePaths.permission, extra: denied);

  Future<void> _upload() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    try {
      await ref.read(tomogramControllerProvider(_opid).notifier).upload();
      if (!mounted) return;
      showFlash(context, l10n.tomogramUploaded, type: FlashType.success);
      Navigator.of(context).maybePop();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      showFlash(context, l10n.tomogramUploadError(e.describe(l10n)), type: FlashType.danger);
    }
  }

  Future<void> _close() async {
    await ref.read(tomogramControllerProvider(_opid).notifier).clearAll();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tomogramControllerProvider(_opid));
    final notifier = ref.read(tomogramControllerProvider(_opid).notifier);

    return LoaderModal(
      visible: state.uploading,
      text: l10n.tomogramUploading,
      child: Scaffold(
        body: Column(
          children: [
            AppHeader(
              title: l10n.commonHeader,
              rightIcon: state.drafts.isEmpty ? null : Icons.check,
              onRightTap: _upload,
            ),
            PatientBar(name: widget.patient.name, onAdd: _add),
            Expanded(
              child: state.drafts.isEmpty
                  ? const TomogramEmptyState()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      children: [
                        for (final d in state.drafts)
                          TomogramCard(
                            key: ValueKey(d.id),
                            draft: d,
                            onDelete: () => notifier.remove(d.id),
                            onDescriptionChanged: (text) => notifier.updateDescription(d.id, text),
                          ),
                      ],
                    ),
            ),
            HideWithKeyboard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppTextField(
                  controller: _opController,
                  label: l10n.tomogramOpNumber,
                  readOnly: true,
                  suffix: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.dim),
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

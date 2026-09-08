import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/permission_gateway.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shown when a required permission was denied. Re-checks on resume and pops
/// once everything is granted.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.permissions});

  final List<Permission> permissions;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _recheck() async {
    final gateway = ref.read(permissionGatewayProvider);
    for (final p in widget.permissions) {
      if (!await gateway.isGranted(p)) return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  String _name(BuildContext context, Permission p) =>
      p == Permission.camera ? context.l10n.permissionCamera : context.l10n.permissionPhotos;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = widget.permissions.isEmpty ? Permission.camera : widget.permissions.first;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.permissionTitle(_name(context, first)), style: AppTextStyles.header, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.permissionBody, style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.permissionGrant,
                color: AppColors.errorRed,
                onPressed: () => ref.read(permissionGatewayProvider).openSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

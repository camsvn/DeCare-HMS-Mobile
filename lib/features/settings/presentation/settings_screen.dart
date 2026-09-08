import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/confirm_dialog.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/presentation/widgets/settings_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onAbout});

  /// Defaults to pushing the About route. Injectable for tests.
  final VoidCallback? onAbout;

  Future<void> _changeUrl(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(context)) return;
    await ref.read(sessionControllerProvider.notifier).logout();
    await ref.read(serverConfigControllerProvider.notifier).reset();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(context)) return;
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: l10n.commonHeader),
          SettingsRow(
            title: l10n.settingsChangeUrl,
            subtitle: l10n.settingsChangeUrlBody,
            onTap: () => _changeUrl(context, ref),
          ),
          const Divider(height: 1, color: AppColors.primary),
          SettingsRow(
            title: l10n.settingsAbout,
            onTap: onAbout ?? () => context.push(RoutePaths.about),
          ),
          const Divider(height: 1, color: AppColors.primary),
          SettingsRow(
            title: l10n.settingsLogout,
            icon: Icons.logout,
            color: AppColors.errorRed,
            onTap: () => _logout(context, ref),
          ),
          const Divider(height: 1, color: AppColors.primary),
        ],
      ),
    );
  }
}

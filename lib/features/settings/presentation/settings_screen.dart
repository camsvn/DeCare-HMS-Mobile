import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/utils/jwt.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/application/app_version_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onAbout});

  /// Defaults to pushing the About route. Injectable for tests.
  final VoidCallback? onAbout;

  Future<void> _changeUrl(
      BuildContext context, WidgetRef ref, String title) async {
    final l10n = context.l10n;
    // Read both notifiers before the await: this row's element is disposed by
    // the redirect the moment the first reset lands. Clearing the URL first
    // sends the gate straight to Configure rather than via Login.
    final serverConfig = ref.read(serverConfigControllerProvider.notifier);
    final session = ref.read(sessionControllerProvider.notifier);
    final confirmed = await showDsDialog(
      context,
      title: title,
      body: l10n.settingsChangeUrlBody,
      confirmLabel: l10n.commonConfirm,
      destructive: true,
    );
    if (!confirmed) return;
    await serverConfig.reset();
    await session.logout();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final session = ref.read(sessionControllerProvider.notifier);
    final confirmed = await showDsDialog(
      context,
      title: l10n.settingsSignOutTitle,
      body: l10n.settingsSignOutBody,
      confirmLabel: l10n.settingsSignOut,
      destructive: true,
    );
    if (!confirmed) return;
    await session.logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.dsType;
    final ds = context.ds;

    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    final host = url == null ? '' : (Uri.tryParse(url)?.host ?? url);
    final token = ref.watch(sessionControllerProvider).valueOrNull?.accessToken;
    final username = token == null ? null : jwtClaim(token, 'username');
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';

    return Scaffold(
      appBar: DsAppBar(
          title: l10n.settingsTabSettings, automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(DsSpace.gutter),
        children: [
          Text(l10n.settingsGroupServer,
              style: type.label.withColor(ds.textSecondary)),
          const SizedBox(height: DsSpace.x2),
          DsCard(
            padding: EdgeInsets.zero,
            child: DsListRow(
              leadingIcon: Icons.dns_outlined,
              title: l10n.settingsChangeUrl,
              trailingValue: host,
              chevron: true,
              onTap: () => _changeUrl(context, ref, l10n.settingsChangeUrl),
            ),
          ),
          const SizedBox(height: DsSpace.x5),
          Text(l10n.settingsGroupAccount,
              style: type.label.withColor(ds.textSecondary)),
          const SizedBox(height: DsSpace.x2),
          DsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DsListRow(
                  leadingIcon: Icons.person_outline,
                  title: l10n.settingsSignedInAs,
                  trailingValue: username ?? '—',
                ),
                DsListRow(
                  leadingIcon: Icons.logout,
                  title: l10n.settingsSignOut,
                  destructive: true,
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpace.x5),
          Text(l10n.settingsGroupHelp,
              style: type.label.withColor(ds.textSecondary)),
          const SizedBox(height: DsSpace.x2),
          DsCard(
            padding: EdgeInsets.zero,
            child: DsListRow(
              leadingIcon: Icons.info_outline,
              title: l10n.settingsAbout,
              chevron: true,
              onTap: onAbout ?? () => context.push(RoutePaths.about),
            ),
          ),
          const SizedBox(height: DsSpace.x6),
          Center(
              child:
                  Text(version, style: type.label.withColor(ds.textSecondary))),
        ],
      ),
    );
  }
}

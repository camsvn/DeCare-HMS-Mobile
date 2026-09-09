import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/utils/jwt.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/dashboard/application/connection_status_controller.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// Navy strip under the app bar: server host, username, connection dot.
class ContextStrip extends ConsumerWidget {
  const ContextStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    final host = url == null ? '' : (Uri.tryParse(url)?.host ?? url);
    final token = ref.watch(sessionControllerProvider).valueOrNull?.accessToken;
    final user = token == null ? null : jwtClaim(token, 'username');
    final status = ref.watch(connectionStatusProvider);
    final checking = status.isLoading;
    final ok = status.valueOrNull ?? false;
    final statusLabel = checking
        ? l10n.dashboardChecking
        : ok
            ? l10n.dashboardConnected
            : l10n.dashboardUnreachable;

    return Container(
      width: double.infinity,
      color: ds.shell,
      padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x2, DsSpace.gutter, DsSpace.x4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host, style: type.mono.withColor(ds.textOnShell), overflow: TextOverflow.ellipsis),
                if (user != null) Text(user, style: type.label.withColor(ds.textOnShellMuted)),
              ],
            ),
          ),
          DsStatusDot(ok: ok, color: checking ? ds.textOnShellMuted : null),
          const SizedBox(width: DsSpace.x2),
          Text(statusLabel, style: type.label.withColor(ds.textOnShellMuted)),
        ],
      ),
    );
  }
}

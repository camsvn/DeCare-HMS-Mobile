import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/utils/jwt.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/dashboard/application/connection_status_controller.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// Navy strip under the app bar: server host, username, queued uploads,
/// connection dot.
///
/// The reachability check re-runs when the app returns to the foreground and
/// when the status is tapped; connectivity changes are handled by the
/// controller itself.
class ContextStrip extends ConsumerStatefulWidget {
  const ContextStrip({super.key});

  @override
  ConsumerState<ContextStrip> createState() => _ContextStripState();
}

class _ContextStripState extends ConsumerState<ContextStrip> with WidgetsBindingObserver {
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

  void _recheck() => ref.read(connectionStatusProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    final host = url == null ? '' : (Uri.tryParse(url)?.host ?? url);
    final token = ref.watch(sessionControllerProvider).valueOrNull?.accessToken;
    final user = token == null ? null : jwtClaim(token, 'username');
    final status = ref.watch(connectionStatusProvider);
    final pending = ref.watch(pendingCountProvider);
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
          // Only surfaced while something is actually waiting, and tappable so
          // the user can see what and retry it.
          if (pending > 0) ...[
            InkWell(
              onTap: () => showPendingUploadsSheet(context),
              borderRadius: BorderRadius.circular(DsRadius.full),
              child: DsChip(text: l10n.dashboardPending(pending), onShell: true),
            ),
            const SizedBox(width: DsSpace.x3),
          ],
          // Tappable so a doubtful reading can be re-checked on the spot.
          Tooltip(
            message: l10n.dashboardRecheck,
            child: InkWell(
              onTap: checking ? null : _recheck,
              borderRadius: BorderRadius.circular(DsRadius.full),
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.x1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsStatusDot(ok: ok, color: checking ? ds.textOnShellMuted : null),
                    const SizedBox(width: DsSpace.x2),
                    Text(statusLabel, style: type.label.withColor(ds.textOnShellMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

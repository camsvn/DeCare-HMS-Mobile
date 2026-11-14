import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/server_reachability.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

const double _iconSize = 20;
const double _retryHeight = 32;

/// A strip that stays put while the last request could not reach the server,
/// so the user learns it once instead of from every tap, with a Retry that
/// pings the server. Collapses to nothing otherwise.
///
/// Taps elsewhere keep working while it shows: the signal may be stale, and a
/// request that gets through clears it.
class ServerUnreachableBanner extends ConsumerStatefulWidget {
  const ServerUnreachableBanner({super.key});

  @override
  ConsumerState<ServerUnreachableBanner> createState() => _ServerUnreachableBannerState();
}

class _ServerUnreachableBannerState extends ConsumerState<ServerUnreachableBanner> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      await ref.read(serverReachabilityProvider.notifier).recheck();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreachable = ref.watch(serverReachabilityProvider) == false;
    return AnimatedSize(
      duration: DsMotion.of(context, DsMotion.base),
      curve: DsMotion.curve,
      alignment: Alignment.topCenter,
      child: unreachable ? _strip(context) : const SizedBox(width: double.infinity),
    );
  }

  Widget _strip(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: ds.shell,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x2, DsSpace.gutter, DsSpace.x2),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: ds.warning, size: _iconSize),
              const SizedBox(width: DsSpace.x3),
              Expanded(
                child: Text(
                  l10n.serverUnreachableBanner,
                  style: context.dsType.body.withColor(ds.textOnShell),
                ),
              ),
              const SizedBox(width: DsSpace.x3),
              DsButton.secondary(
                label: l10n.commonRetry,
                onPressed: _retry,
                loading: _checking,
                expand: false,
                height: _retryHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

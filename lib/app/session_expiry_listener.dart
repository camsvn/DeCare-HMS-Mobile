import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';

/// Signs the user out when the network layer reports that the session is dead,
/// and says why. Lives above the router so the banner survives the redirect
/// back to the login screen.
class SessionExpiryListener extends ConsumerStatefulWidget {
  const SessionExpiryListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionExpiryListener> createState() => _SessionExpiryListenerState();
}

class _SessionExpiryListenerState extends ConsumerState<SessionExpiryListener> {
  /// The counter value already acted on, so the same bump delivered twice
  /// cannot sign the user out twice.
  int? _handled;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(authFailureProvider, (prev, next) {
      if (prev == next || _handled == next) return;
      // Already signed out: a manual sign-out, or a later 401 from the same
      // burst — `logout` drops the session synchronously, so every bump after
      // the first stops here and the user gets one sign-out and one banner.
      final session = ref.read(sessionControllerProvider).valueOrNull;
      if (session == null) return;
      _handled = next;
      ref.read(sessionControllerProvider.notifier).logout();
      final ctx = rootNavigatorKey.currentContext;
      final overlay = rootNavigatorKey.currentState?.overlay;
      if (ctx != null && overlay != null) {
        showDsBannerIn(overlay, ctx.l10n.errorSessionExpired, kind: DsBannerKind.danger);
      }
    });
    return widget.child;
  }
}

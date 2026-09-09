import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/auth/auth.dart';

/// Signs the user out when the network layer reports that the session is dead,
/// and says why. Lives above the router so the banner survives the redirect
/// back to the login screen.
class SessionExpiryListener extends ConsumerWidget {
  const SessionExpiryListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(authFailureProvider, (prev, next) {
      if (prev == next) return;
      // Already signed out (a manual sign-out, or a second 401 in the burst).
      final session = ref.read(sessionControllerProvider).valueOrNull;
      if (session == null) return;
      ref.read(sessionControllerProvider.notifier).logout();
      final ctx = rootNavigatorKey.currentContext;
      final overlay = rootNavigatorKey.currentState?.overlay;
      if (ctx != null && overlay != null) {
        showDsBannerIn(overlay, AppLocalizations.of(ctx).errorSessionExpired, kind: DsBannerKind.danger);
      }
    });
    return child;
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

/// Describes one workflow module. Features export one of these; the app
/// registers them in `lib/app/modules.dart`.
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entryRoute,
    required this.routes,
    this.badge,
  });

  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final IconData icon;
  final String entryRoute;

  /// Routes nested under the Home tab branch.
  final List<RouteBase> routes;

  /// Optional live badge for the dashboard card.
  final Widget Function(WidgetRef ref)? badge;
}

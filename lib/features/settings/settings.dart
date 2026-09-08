import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/settings/presentation/about_screen.dart';
import 'package:hms_uploader/features/settings/presentation/settings_screen.dart';

export 'presentation/about_screen.dart';
export 'presentation/settings_screen.dart';

final GoRoute aboutRoute = GoRoute(
  path: RoutePaths.aboutPattern,
  builder: (context, state) => const AboutScreen(),
);

GoRoute settingsRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsScreen(),
      routes: children,
    );

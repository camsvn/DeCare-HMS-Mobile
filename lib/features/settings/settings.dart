import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/settings/presentation/about_screen.dart';
import 'package:hms_uploader/features/settings/presentation/settings_screen.dart';

export 'presentation/about_screen.dart';
export 'presentation/settings_screen.dart';

final GoRoute aboutRoute = GoRoute(
  path: RoutePaths.aboutPattern,
  pageBuilder: (context, state) => FadeThroughPage(key: state.pageKey, child: const AboutScreen()),
);

GoRoute settingsRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.settings,
      pageBuilder: (context, state) => FadeThroughPage(key: state.pageKey, child: const SettingsScreen()),
      routes: children,
    );

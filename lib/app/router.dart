import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/app_shell.dart';
import 'package:hms_uploader/app/modules.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/navigator_keys.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/dashboard/dashboard.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/settings.dart';

// The key moved to `core` so features can name it as a `parentNavigatorKey`;
// re-exported so `rootNavigatorKey` still resolves through this file.
export 'package:hms_uploader/core/navigation/navigator_keys.dart';

/// The three-way gate from the React Native `AppNavigator`.
String? computeRedirect({required String location, required bool hasServerUrl, required bool sessionValid}) {
  const authScreens = {RoutePaths.login, RoutePaths.configure};
  if (!hasServerUrl) {
    return location == RoutePaths.configure ? null : RoutePaths.configure;
  }
  if (!sessionValid) {
    return authScreens.contains(location) ? null : RoutePaths.login;
  }
  return authScreens.contains(location) ? RoutePaths.dashboard : null;
}

/// Notifies the router when the server URL or the session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(serverConfigControllerProvider, (_, _) => notifyListeners());
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(
      location: state.matchedLocation,
      hasServerUrl: ref.read(serverConfigControllerProvider).valueOrNull != null,
      sessionValid: ref.read(sessionControllerProvider).valueOrNull?.isValid() ?? false,
    ),
    routes: [
      configureRoute,
      loginRoute,
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => FadeThroughPage(
          key: state.pageKey,
          child: AppShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(routes: [
            dashboardRoute(modules: appModules),
            for (final m in appModules) ...m.routes,
          ]),
          StatefulShellBranch(routes: [settingsRoute(children: [aboutRoute])]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

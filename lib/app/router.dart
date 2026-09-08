import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/app_shell.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The three-way gate from the React Native `AppNavigator`.
String? computeRedirect({required String location, required bool hasServerUrl, required bool sessionValid}) {
  const authScreens = {RoutePaths.login, RoutePaths.configure};
  if (!hasServerUrl) {
    return location == RoutePaths.configure ? null : RoutePaths.configure;
  }
  if (!sessionValid) {
    return authScreens.contains(location) ? null : RoutePaths.login;
  }
  return authScreens.contains(location) ? RoutePaths.home : null;
}

/// Notifies the router when the server URL or the session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(serverConfigControllerProvider, (_, __) => notifyListeners());
    ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
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
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [homeRoute(children: tomogramRoutes)]),
          StatefulShellBranch(routes: [settingsRoute(children: [aboutRoute])]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

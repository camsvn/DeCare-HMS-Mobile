import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/presentation/login_screen.dart';

export 'application/session_controller.dart';
export 'data/auth_api.dart';
export 'data/session.dart';
export 'data/session_repository.dart';
export 'presentation/login_screen.dart';

final GoRoute loginRoute = GoRoute(
  path: RoutePaths.login,
  builder: (context, state) => const LoginScreen(),
);

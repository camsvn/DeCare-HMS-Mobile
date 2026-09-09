import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/server_config/presentation/configure_url_screen.dart';

export 'application/server_config_controller.dart';
export 'data/health_check_api.dart';
export 'data/server_config_repository.dart';
export 'presentation/configure_url_screen.dart';

final GoRoute configureRoute = GoRoute(
  path: RoutePaths.configure,
  pageBuilder: (context, state) => FadeThroughPage(key: state.pageKey, child: const ConfigureUrlScreen()),
);

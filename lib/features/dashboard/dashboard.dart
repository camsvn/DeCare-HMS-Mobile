import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/dashboard/presentation/dashboard_screen.dart';

export 'application/connection_status_controller.dart';
export 'presentation/dashboard_screen.dart';

GoRoute dashboardRoute({required List<AppModule> modules}) => GoRoute(
      path: RoutePaths.dashboard,
      pageBuilder: (context, state) => FadeThroughPage(
        key: state.pageKey,
        child: DashboardScreen(modules: modules),
      ),
    );

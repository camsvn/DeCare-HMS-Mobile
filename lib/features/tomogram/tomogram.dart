import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/presentation/permission_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/tomogram_screen.dart';
import 'package:permission_handler/permission_handler.dart';

export 'application/media_picker_service.dart';
export 'application/permission_gateway.dart';
export 'application/tomogram_controller.dart';
export 'data/tomogram_api.dart';
export 'data/tomogram_draft.dart';
export 'data/upload_result.dart';
export 'presentation/permission_screen.dart';
export 'presentation/tomogram_screen.dart';

/// Nested under the home route.
final List<RouteBase> tomogramRoutes = [
  GoRoute(
    path: RoutePaths.tomogramPattern,
    builder: (context, state) {
      final extra = state.extra;
      final opid = int.tryParse(state.pathParameters['opid'] ?? '') ?? 0;
      final patient = extra is Patient ? extra : Patient(id: 0, opid: opid, name: '');
      return TomogramScreen(patient: patient);
    },
  ),
  GoRoute(
    path: RoutePaths.permissionPattern,
    builder: (context, state) {
      final extra = state.extra;
      final permissions = extra is List<Permission> ? extra : const <Permission>[];
      return PermissionScreen(permissions: permissions);
    },
  ),
];

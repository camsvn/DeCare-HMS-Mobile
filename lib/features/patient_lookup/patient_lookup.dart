import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/home_screen.dart';

export 'application/patient_lookup_controller.dart';
export 'application/recent_searches_controller.dart';
export 'data/op_register_api.dart';
export 'data/patient.dart';
export 'data/recent_searches_repository.dart';
export 'presentation/home_screen.dart';

/// Home route. [children] are nested routes (tomogram, permission) supplied by
/// the router so this feature does not depend on them.
GoRoute homeRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => HomeScreen(
        onPatientSelected: (patient) => context.push(RoutePaths.tomogram(patient.opid), extra: patient),
      ),
      routes: children,
    );

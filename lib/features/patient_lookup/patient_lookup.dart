import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/patient_lookup_screen.dart';

export 'application/patient_lookup_controller.dart';
export 'application/recent_searches_controller.dart';
export 'data/op_register_api.dart';
export 'data/patient.dart';
export 'data/recent_searches_repository.dart';
export 'presentation/patient_lookup_screen.dart';

/// Entry route of the tomogram module. [children] are nested routes
/// (tomogram detail, permission) supplied by the module so this feature does
/// not depend on them.
GoRoute patientLookupRoute({List<RouteBase> children = const []}) => GoRoute(
      path: RoutePaths.tomogramEntry,
      pageBuilder: (context, state) => FadeThroughPage(
        key: state.pageKey,
        child: PatientLookupScreen(
          // push() completes when the tomogram route is popped, which is when
          // the screen adds the patient to recents.
          onPatientSelected: (patient) => context.push(RoutePaths.tomogram(patient.opid), extra: patient),
        ),
      ),
      routes: children,
    );

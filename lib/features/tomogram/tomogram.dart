import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/presentation/permission_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/tomogram_screen.dart';
import 'package:permission_handler/permission_handler.dart';

export 'application/media_picker_service.dart';
export 'application/permission_gateway.dart';
export 'application/tomogram_controller.dart';
export 'application/tomogram_history_controller.dart';
export 'data/tomogram_api.dart';
export 'data/tomogram_draft.dart';
export 'data/tomogram_history_api.dart';
export 'data/tomogram_set.dart';
export 'data/upload_result.dart';
export 'presentation/permission_screen.dart';
export 'presentation/tomogram_screen.dart';
export 'presentation/widgets/tomogram_history_card.dart';

/// `/app/tomogram/:opid`, nested under the module entry route.
final GoRoute tomogramDetailRoute = GoRoute(
  path: RoutePaths.tomogramPattern,
  pageBuilder: (context, state) {
    final extra = state.extra;
    final opid = int.tryParse(state.pathParameters['opid'] ?? '') ?? 0;
    final patient = extra is Patient ? extra : Patient(id: 0, opid: opid, name: '');
    return FadeThroughPage(key: state.pageKey, child: TomogramScreen(patient: patient));
  },
);

/// `/app/tomogram/permission`, nested under the module entry route.
final GoRoute permissionRoute = GoRoute(
  path: RoutePaths.permissionPattern,
  pageBuilder: (context, state) {
    final extra = state.extra;
    final permissions = extra is List<Permission> ? extra : const <Permission>[];
    return FadeThroughPage(key: state.pageKey, child: PermissionScreen(permissions: permissions));
  },
);

final AppModule tomogramModule = AppModule(
  id: 'tomogram',
  title: (l10n) => l10n.tomogramModuleTitle,
  subtitle: (l10n) => l10n.tomogramModuleSubtitle,
  icon: Icons.photo_camera_back_outlined,
  entryRoute: RoutePaths.tomogramEntry,
  // `permissionRoute` first: go_router matches sub-routes in order.
  routes: [patientLookupRoute(children: [permissionRoute, tomogramDetailRoute])],
  badge: (ref) {
    final count = ref.watch(recentSearchesControllerProvider).length;
    return count == 0 ? const SizedBox.shrink() : DsChip(text: '$count', mono: true);
  },
);

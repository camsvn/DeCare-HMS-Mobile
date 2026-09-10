import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/navigation/navigator_keys.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/presentation/capture_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/permission_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/tomogram_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/recent_count_badge.dart';
import 'package:permission_handler/permission_handler.dart';

// Connectivity lives in core (the dashboard uses it too); re-exported for callers of this barrel.
export 'package:hms_uploader/core/network/connectivity_service.dart';
export 'application/camera_service.dart';
export 'application/capture_controller.dart';
export 'application/capture_grid_controller.dart';
export 'application/description_suggestions.dart';
export 'application/jpeg_orientation.dart';
export 'application/media_picker_service.dart';
export 'application/permission_gateway.dart';
export 'application/recent_labels_controller.dart';
export 'application/tomogram_controller.dart';
export 'application/tomogram_history_controller.dart';
export 'application/upload_queue_controller.dart';
export 'data/pending_upload.dart';
export 'data/pending_uploads_repository.dart';
export 'data/recent_labels_repository.dart';
export 'data/shot.dart';
export 'data/tomogram_api.dart';
export 'data/tomogram_draft.dart';
export 'data/tomogram_history_api.dart';
export 'data/tomogram_set.dart';
export 'data/upload_result.dart';
export 'presentation/capture_screen.dart';
export 'presentation/draft_preview_screen.dart';
export 'presentation/permission_screen.dart';
export 'presentation/shot_preview_screen.dart';
export 'presentation/tomogram_screen.dart';
export 'presentation/widgets/label_pill.dart';
export 'presentation/widgets/label_sheet.dart';
export 'presentation/widgets/pending_line.dart';
export 'presentation/widgets/pending_uploads_sheet.dart';
export 'presentation/widgets/photo_viewer.dart';
export 'presentation/widgets/recent_count_badge.dart';
export 'presentation/widgets/shot_strip.dart';
export 'presentation/widgets/shutter_button.dart';
export 'presentation/widgets/suggestion_chips.dart';
export 'presentation/widgets/tomogram_history_card.dart';

/// `/app/tomogram/:opid/capture`, nested under the tomogram screen it hands
/// its photos back to. On the root navigator, so the capture screen covers the
/// tab bar the way a camera should.
final GoRoute captureRoute = GoRoute(
  path: RoutePaths.capturePattern,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    final opid = int.tryParse(state.pathParameters['opid'] ?? '') ?? 0;
    return FadeThroughPage(key: state.pageKey, child: CaptureScreen(opid: opid));
  },
);

/// `/app/tomogram/:opid`, nested under the module entry route.
final GoRoute tomogramDetailRoute = GoRoute(
  path: RoutePaths.tomogramPattern,
  routes: [captureRoute],
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
  badge: () => const RecentCountBadge(),
);

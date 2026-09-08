import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin seam over permission_handler so controllers and screens are testable.
abstract class PermissionGateway {
  Future<bool> request(Permission permission);
  Future<bool> isGranted(Permission permission);
  Future<bool> openSettings();
}

class HandlerPermissionGateway implements PermissionGateway {
  @override
  Future<bool> request(Permission permission) async {
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

final permissionGatewayProvider = Provider<PermissionGateway>((ref) => HandlerPermissionGateway());

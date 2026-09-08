import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/jpeg.dart';
import 'package:hms_uploader/features/tomogram/application/permission_gateway.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaSource { camera, gallery }

/// The React Native app allowed two gallery images per pick.
const int galleryPickLimit = 2;

class MediaPickResult {
  const MediaPickResult({required this.accepted, required this.rejected});

  final List<String> accepted;
  final int rejected;

  static const empty = MediaPickResult(accepted: [], rejected: 0);
}

abstract class MediaPickerService {
  List<Permission> permissionsFor(MediaSource source);
  Future<List<Permission>> deniedPermissions(MediaSource source);
  Future<MediaPickResult> pick(MediaSource source);
}

class DefaultMediaPickerService implements MediaPickerService {
  DefaultMediaPickerService({required ImagePicker picker, required PermissionGateway permissions})
      : _picker = picker,
        _permissions = permissions;

  final ImagePicker _picker;
  final PermissionGateway _permissions;

  @override
  List<Permission> permissionsFor(MediaSource source) => switch (source) {
        MediaSource.camera => const [Permission.camera],
        MediaSource.gallery => const [Permission.photos],
      };

  @override
  Future<List<Permission>> deniedPermissions(MediaSource source) async {
    final denied = <Permission>[];
    for (final p in permissionsFor(source)) {
      if (!await _permissions.request(p)) denied.add(p);
    }
    return denied;
  }

  @override
  Future<MediaPickResult> pick(MediaSource source) async {
    final files = switch (source) {
      MediaSource.camera => [await _picker.pickImage(source: ImageSource.camera)],
      MediaSource.gallery => await _picker.pickMultiImage(),
    };
    final accepted = <String>[];
    var rejected = 0;
    for (final f in files) {
      if (f == null) continue;
      if (!await isJpegFile(f.path)) {
        rejected++;
        continue;
      }
      if (accepted.length < galleryPickLimit) accepted.add(f.path);
    }
    return MediaPickResult(accepted: accepted, rejected: rejected);
  }
}

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => DefaultMediaPickerService(picker: ImagePicker(), permissions: ref.watch(permissionGatewayProvider)),
);

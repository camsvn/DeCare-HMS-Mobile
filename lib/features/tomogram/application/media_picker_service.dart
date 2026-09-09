import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/jpeg.dart';
import 'package:hms_uploader/features/tomogram/application/permission_gateway.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaSource { camera, gallery }

/// The React Native app allowed two gallery images per pick.
const int galleryPickLimit = 2;

/// Captures and gallery picks are downscaled to fit this box and re-encoded as
/// JPEG at [pickerQuality]: a 12 MP phone photo is several megabytes, which is
/// a slow upload on clinic wifi and larger than the record needs.
const double pickerMaxDimension = 2000;
const int pickerQuality = 85;

class MediaPickResult {
  const MediaPickResult({required this.accepted, required this.rejected, this.overLimit = 0});

  final List<String> accepted;

  /// JPEG-check failures.
  final int rejected;

  /// JPEGs the user picked beyond [galleryPickLimit], so the screen can say so
  /// instead of dropping them silently.
  final int overLimit;

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

  /// Only the camera needs a runtime permission. Gallery picking goes through
  /// the system picker (`ACTION_GET_CONTENT` / the Android photo picker), which
  /// grants per-file read access without any manifest permission on every API
  /// level. Asking for [Permission.photos] here would be a dead end below API
  /// 33, where permission_handler maps it to no manifest permission and
  /// auto-denies it without ever showing a dialog.
  @override
  List<Permission> permissionsFor(MediaSource source) => switch (source) {
        MediaSource.camera => const [Permission.camera],
        MediaSource.gallery => const <Permission>[],
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
      MediaSource.camera => [
          await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: pickerMaxDimension,
            maxHeight: pickerMaxDimension,
            imageQuality: pickerQuality,
          ),
        ],
      MediaSource.gallery => await _picker.pickMultiImage(
          maxWidth: pickerMaxDimension,
          maxHeight: pickerMaxDimension,
          imageQuality: pickerQuality,
        ),
    };
    final accepted = <String>[];
    var rejected = 0;
    var overLimit = 0;
    for (final f in files) {
      if (f == null) continue;
      if (!await isJpegFile(f.path)) {
        rejected++;
        continue;
      }
      if (accepted.length < galleryPickLimit) {
        accepted.add(f.path);
      } else {
        overLimit++;
      }
    }
    return MediaPickResult(accepted: accepted, rejected: rejected, overLimit: overLimit);
  }
}

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => DefaultMediaPickerService(picker: ImagePicker(), permissions: ref.watch(permissionGatewayProvider)),
);

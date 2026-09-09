import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class MockPermissionGateway extends Mock implements PermissionGateway {}

void main() {
  late Directory dir;
  late MockImagePicker picker;
  late MockPermissionGateway permissions;
  late DefaultMediaPickerService service;

  setUpAll(() => registerFallbackValue(Permission.camera));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('picker');
    picker = MockImagePicker();
    permissions = MockPermissionGateway();
    service = DefaultMediaPickerService(picker: picker, permissions: permissions);
  });
  tearDown(() => dir.delete(recursive: true));

  File jpeg(String n) => File('${dir.path}/$n')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
  File png(String n) => File('${dir.path}/$n')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

  test('deniedPermissions requests and returns what was refused', () async {
    when(() => permissions.request(Permission.camera)).thenAnswer((_) async => false);
    expect(await service.deniedPermissions(MediaSource.camera), [Permission.camera]);
  });

  test('gallery needs no runtime permission, so nothing is requested', () async {
    expect(service.permissionsFor(MediaSource.gallery), isEmpty);
    expect(await service.deniedPermissions(MediaSource.gallery), isEmpty);
    verifyNever(() => permissions.request(any()));
  });

  test('gallery pick keeps at most two JPEGs and counts rejects and over-limit picks', () async {
    final a = jpeg('a.jpg');
    final b = png('b.png');
    final c = jpeg('c.jpg');
    final d = jpeg('d.jpg');
    when(() => picker.pickMultiImage(maxWidth: any(named: 'maxWidth'), maxHeight: any(named: 'maxHeight'), imageQuality: any(named: 'imageQuality')))
        .thenAnswer((_) async => [XFile(a.path), XFile(b.path), XFile(c.path), XFile(d.path)]);
    final result = await service.pick(MediaSource.gallery);
    expect(result.accepted, [a.path, c.path]);
    expect(result.rejected, 1);
    expect(result.overLimit, 1);
  });

  test('camera pick returns single JPEG or nothing', () async {
    final a = jpeg('a.jpg');
    when(() => picker.pickImage(
          source: ImageSource.camera,
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => XFile(a.path));
    expect((await service.pick(MediaSource.camera)).accepted, [a.path]);
    when(() => picker.pickImage(
          source: ImageSource.camera,
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => null);
    expect((await service.pick(MediaSource.camera)).accepted, isEmpty);
  });

  test('the camera capture is resized and re-encoded so uploads stay small', () async {
    final a = jpeg('a.jpg');
    when(() => picker.pickImage(
          source: ImageSource.camera,
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => XFile(a.path));

    await service.pick(MediaSource.camera);

    verify(() => picker.pickImage(source: ImageSource.camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 85)).called(1);
    expect(pickerMaxDimension, 2000);
    expect(pickerQuality, 85);
  });

  test('gallery picks are resized and re-encoded too', () async {
    when(() => picker.pickMultiImage(maxWidth: any(named: 'maxWidth'), maxHeight: any(named: 'maxHeight'), imageQuality: any(named: 'imageQuality')))
        .thenAnswer((_) async => []);

    await service.pick(MediaSource.gallery);

    verify(() => picker.pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 85)).called(1);
  });
}

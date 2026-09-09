import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../helpers/pump_app.dart';

class MockPermissionGateway extends Mock implements PermissionGateway {}

void main() {
  setUpAll(() => registerFallbackValue(Permission.camera));

  testWidgets('names the first denied permission and opens settings', (tester) async {
    final gateway = MockPermissionGateway();
    when(() => gateway.openSettings()).thenAnswer((_) async => true);
    when(() => gateway.isGranted(any())).thenAnswer((_) async => false);
    await pumpApp(
      tester,
      const PermissionScreen(permissions: [Permission.camera, Permission.photos]),
      overrides: [permissionGatewayProvider.overrideWithValue(gateway)],
    );
    expect(find.text('DeCare HMS'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Grant Permission to access Camera'), findsOneWidget);
    await tester.tap(find.text('Grant Permission'));
    await tester.pump();
    verify(() => gateway.openSettings()).called(1);
  });
}

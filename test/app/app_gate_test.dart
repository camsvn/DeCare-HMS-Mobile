import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helpers/signed_in_container.dart';

void main() {
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('gate_docs'));
  tearDown(() => docs.delete(recursive: true));
  testWidgets('starts on configure when no url', (tester) async {
    final c = (await signedInContainer(docs: docs, url: null, session: false)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Connect to your server'), findsOneWidget);
  });

  testWidgets('starts on login when url but no session', (tester) async {
    final c = (await signedInContainer(docs: docs, session: false)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('starts on the dashboard when session is valid, and logout returns to login', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
    expect(find.byType(ModuleCard), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('tapping the Tomogram module opens the patient lookup', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomogram').first);
    await tester.pumpAndSettle();
    expect(find.text('Enter OP Number'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
  });

  testWidgets('/app/tomogram/permission opens the permission screen, not the detail screen', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();

    c.read(routerProvider).push(RoutePaths.permission, extra: <Permission>[Permission.camera]);
    await tester.pumpAndSettle();
    expect(find.byType(PermissionScreen), findsOneWidget);
    expect(find.byType(TomogramScreen), findsNothing);
  });

  testWidgets('/app/tomogram/:opid opens the tomogram detail screen', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();

    c.read(routerProvider).push(RoutePaths.tomogram(5), extra: const Patient(id: 1, opid: 5, name: 'Jane'));
    await tester.pumpAndSettle();
    expect(find.byType(TomogramScreen), findsOneWidget);
    expect(find.byType(PermissionScreen), findsNothing);
  });

  testWidgets('system back on the Home tab arms double-press-to-exit', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('App: Press back again to exit'), findsOneWidget);
    // Still on Home: the shell swallowed the pop instead of exiting.
    expect(find.text('Modules'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('system back on the Settings tab returns to the Home tab', (tester) async {
    final c = (await signedInContainer(docs: docs)).container;
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
  });
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

import '../helpers/signed_in_container.dart';

void main() {
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('expiry_docs'));
  tearDown(() => docs.delete(recursive: true));
  testWidgets('an auth failure signs out, returns to login and warns the user', (tester) async {
    resetDsBannersForTest();
    final (container: c, :store) = await signedInContainer(docs: docs);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(await store.read('refresh_token'), isNull);
    expect(await store.read('access_token'), isNull);
    expect(find.text('Session expired, please sign in again'), findsOneWidget);

    // Let the banner's dismiss timer run out before the tree is torn down.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a burst of auth failures signs out once and shows one banner', (tester) async {
    resetDsBannersForTest();
    final (container: c, :store) = await signedInContainer(docs: docs);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    // Three parallel requests all coming back 401.
    c.read(authFailureProvider.notifier).state++;
    c.read(authFailureProvider.notifier).state++;
    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(await store.read('refresh_token'), isNull);
    expect(find.text('Session expired, please sign in again'), findsOneWidget);

    // Banners are queued one at a time, so a second enqueued banner would only
    // show up once the first has been dismissed.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Session expired, please sign in again'), findsNothing);
  });

  testWidgets('an auth failure with no session does nothing', (tester) async {
    resetDsBannersForTest();
    final (container: c, store: _) = await signedInContainer(docs: docs, session: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);

    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Session expired, please sign in again'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/features/settings/settings.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders sections with the current year', (tester) async {
    await pumpApp(tester, const AboutScreen());
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.textContaining('© ${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('licence text names no particular client', (tester) async {
    await pumpApp(tester, const AboutScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('Cutis'), findsNothing);
    expect(find.textContaining('licensed to the hospital'), findsOneWidget);
  });

  testWidgets('contact links are tappable rows aligned with the text', (tester) async {
    await pumpApp(tester, const AboutScreen());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('decare.team'), 300);

    final phone = find.ancestor(of: find.text('+91 80863 58930'), matching: find.byType(DsListRow));
    final site = find.ancestor(of: find.text('decare.team'), matching: find.byType(DsListRow));
    expect(phone, findsOneWidget);
    expect(site, findsOneWidget);
    expect(tester.widget<DsListRow>(phone).onTap, isNotNull);
    expect(tester.widget<DsListRow>(site).onTap, isNotNull);

    // Rows are left-aligned: their leading icons sit on the heading's left edge
    // and the two labels start at the same x.
    final headingLeft = tester.getTopLeft(find.text('Contact Us')).dx;
    Finder tileOf(IconData icon) => find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)).first;
    expect(tester.getTopLeft(tileOf(Icons.phone_outlined)).dx, headingLeft);
    expect(tester.getTopLeft(tileOf(Icons.language_outlined)).dx, headingLeft);
    expect(tester.getTopLeft(find.text('+91 80863 58930')).dx, tester.getTopLeft(find.text('decare.team')).dx);
  });

  testWidgets('contact block survives a large text scale without overflowing', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('decare.team'), 300);
    // A RenderFlex overflow is reported through FlutterError and fails the test.
    expect(tester.takeException(), isNull);
  });
}

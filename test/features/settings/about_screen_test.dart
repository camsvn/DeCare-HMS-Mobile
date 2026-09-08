import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('+91 80863 58930'), findsOneWidget);
  });
}

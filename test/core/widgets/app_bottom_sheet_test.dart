import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/widgets/app_bottom_sheet.dart';

/// The app shows sheets from screens that live inside a nested (tab branch)
/// navigator. Selecting an item must close the sheet and return its value
/// without popping the screen underneath.
void main() {
  testWidgets('item pops the sheet, not the nested screen', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showAppBottomSheet<String>(
                    context,
                    builder: (sheet) => [
                      ListTile(title: const Text('Pick me'), onTap: () => Navigator.of(sheet).pop('picked')),
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick me'), findsOneWidget);

    await tester.tap(find.text('Pick me'));
    await tester.pumpAndSettle();

    expect(result, 'picked');
    expect(find.text('Pick me'), findsNothing);
    expect(find.text('open'), findsOneWidget, reason: 'the screen under the sheet must survive');
  });
}

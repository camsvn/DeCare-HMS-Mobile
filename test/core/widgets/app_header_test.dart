import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';

void main() {
  testWidgets('fills the full width inside a centring Column', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [AppHeader(title: 'DeCare HMS', rightIcon: Icons.check)]),
      ),
    ));
    final headerSize = tester.getSize(find.byType(AppHeader));
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(headerSize.width, screenWidth);

    // The right icon sits at the edge, not on top of the title.
    final title = tester.getRect(find.text('DeCare HMS'));
    final icon = tester.getRect(find.byIcon(Icons.check));
    expect(icon.left, greaterThan(title.right));
  });
}

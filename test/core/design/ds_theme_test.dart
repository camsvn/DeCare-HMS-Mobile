import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('theme exposes tokens through context extensions', (tester) async {
    late DsColors ds;
    late DsType type;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Builder(builder: (context) {
        ds = context.ds;
        type = context.dsType;
        return const SizedBox();
      }),
    ));
    expect(ds.shell, const Color(0xFF151D28));
    expect(ds.canvas, const Color(0xFFF4F6FA));
    expect(ds.accentGradient.colors, hasLength(3));
    expect(type.body.fontFamily, 'Inter');
    expect(type.body.fontSize, 14);
    expect(type.title.fontWeight, FontWeight.w600);
    expect(type.mono.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(type.body.color, ds.textPrimary);
  });

  test('DsMotion.of collapses to fast when animations are disabled', () {
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: true), DsMotion.fast);
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: false),
        const Duration(milliseconds: 320));
  });
}

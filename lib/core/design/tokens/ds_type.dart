import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_colors.dart';

/// The six text styles. All default to `textPrimary`; use `withColor` for
/// secondary or on-shell text.
class DsType extends ThemeExtension<DsType> {
  const DsType({
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.label,
    required this.mono,
  });

  static const String family = 'Inter';

  /// How far the shell chrome (app bar, bottom bar) follows the reader's text
  /// size. Content scales without limit; chrome stops here so that it cannot
  /// swallow the screen it frames.
  static const double barScaleMax = 1.3;

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle label;
  final TextStyle mono;

  factory DsType.inter(DsColors colors) {
    final c = colors.textPrimary;
    return DsType(
      display: TextStyle(fontFamily: family, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: c),
      title: TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, color: c),
      heading: TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: c),
      body: TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: c),
      label: TextStyle(
          fontFamily: family, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3, height: 1.3, color: c),
      mono: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  @override
  DsType copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? label,
    TextStyle? mono,
  }) =>
      DsType(
        display: display ?? this.display,
        title: title ?? this.title,
        heading: heading ?? this.heading,
        body: body ?? this.body,
        label: label ?? this.label,
        mono: mono ?? this.mono,
      );

  @override
  DsType lerp(DsType? other, double t) {
    if (other == null) return this;
    return DsType(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}

extension DsTextStyleX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
}

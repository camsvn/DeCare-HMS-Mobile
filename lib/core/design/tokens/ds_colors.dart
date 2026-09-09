import 'package:flutter/material.dart';

/// Semantic colour tokens. Screens read these through `context.ds`; nothing
/// outside this file names a raw colour.
class DsColors extends ThemeExtension<DsColors> {
  const DsColors({
    required this.canvas,
    required this.card,
    required this.shell,
    required this.shellRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnShell,
    required this.textOnShellMuted,
    required this.borderSubtle,
    required this.accentSolid,
    required this.accentGradient,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color card;
  final Color shell;
  final Color shellRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnShell;
  final Color textOnShellMuted;
  final Color borderSubtle;
  final Color accentSolid;
  final LinearGradient accentGradient;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = DsColors(
    canvas: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    shell: Color(0xFF151D28),
    shellRaised: Color(0xFF1E2938),
    textPrimary: Color(0xFF121826),
    textSecondary: Color(0xFF5B6472),
    textOnShell: Color(0xFFFFFFFF),
    textOnShellMuted: Color(0xB3FFFFFF),
    borderSubtle: Color(0xFFE3E7EE),
    accentSolid: Color(0xFF2F8FE5),
    accentGradient: LinearGradient(
      colors: [Color(0xFF6D5BD0), Color(0xFF2F8FE5), Color(0xFF10B394)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    success: Color(0xFF1F9D6A),
    warning: Color(0xFFE0A100),
    danger: Color(0xFFE5484D),
  );

  @override
  DsColors copyWith({
    Color? canvas,
    Color? card,
    Color? shell,
    Color? shellRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnShell,
    Color? textOnShellMuted,
    Color? borderSubtle,
    Color? accentSolid,
    LinearGradient? accentGradient,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return DsColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      shell: shell ?? this.shell,
      shellRaised: shellRaised ?? this.shellRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnShell: textOnShell ?? this.textOnShell,
      textOnShellMuted: textOnShellMuted ?? this.textOnShellMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentSolid: accentSolid ?? this.accentSolid,
      accentGradient: accentGradient ?? this.accentGradient,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  DsColors lerp(DsColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DsColors(
      canvas: c(canvas, other.canvas),
      card: c(card, other.card),
      shell: c(shell, other.shell),
      shellRaised: c(shellRaised, other.shellRaised),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textOnShell: c(textOnShell, other.textOnShell),
      textOnShellMuted: c(textOnShellMuted, other.textOnShellMuted),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      accentSolid: c(accentSolid, other.accentSolid),
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t)!,
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
    );
  }
}

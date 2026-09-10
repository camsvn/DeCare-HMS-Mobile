import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.hintMaxLines,
    this.errorText,
    this.mono = false,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.showCounter = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;

  /// Caps the placeholder at this many lines, ellipsising the rest. A long
  /// hint on a short field would otherwise be a single clipped line.
  final int? hintMaxLines;

  final String? errorText;
  final bool mono;
  final bool obscureText;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final style = (mono ? type.mono : type.body).withColor(ds.textPrimary);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: DsRadius.smallAll,
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: type.label.withColor(ds.textSecondary)),
          const SizedBox(height: DsSpace.x1),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: style,
          cursorColor: ds.accentSolid,
          decoration: InputDecoration(
            hintText: hint,
            hintMaxLines: hintMaxLines,
            hintStyle: style.withColor(ds.textSecondary),
            errorText: errorText,
            errorStyle: type.label.withColor(ds.danger),
            counterText: showCounter ? null : '',
            counterStyle: type.label.withColor(ds.textSecondary),
            filled: true,
            fillColor: ds.card,
            isDense: true,
            prefixIcon: prefix,
            suffixIcon: suffix,
            prefixIconColor: ds.textSecondary,
            suffixIconColor: ds.textSecondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.x3, vertical: DsSpace.x3),
            enabledBorder: border(ds.borderSubtle),
            focusedBorder: border(ds.accentSolid, 2),
            errorBorder: border(ds.danger),
            focusedErrorBorder: border(ds.danger, 2),
            disabledBorder: border(ds.borderSubtle),
            border: border(ds.borderSubtle),
          ),
        ),
      ],
    );
  }
}

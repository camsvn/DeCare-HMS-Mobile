import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Numeric OP-number field with clear and submit buttons.
class OpSearchBar extends StatefulWidget {
  const OpSearchBar({super.key, required this.onSubmit});

  final ValueChanged<int> onSubmit;

  @override
  State<OpSearchBar> createState() => _OpSearchBarState();
}

class _OpSearchBarState extends State<OpSearchBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final opid = int.tryParse(_controller.text.trim());
    if (opid == null) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(opid);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _controller,
              hint: context.l10n.homeSearchPlaceholder,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 7,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              suffix: hasText
                  ? IconButton(icon: const Icon(Icons.close, color: AppColors.dim), onPressed: _controller.clear)
                  : const Icon(Icons.search, color: AppColors.dim),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.check, color: AppColors.goGreen),
              onPressed: _submit,
            ),
          ],
        ],
      ),
    );
  }
}

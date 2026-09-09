import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Numeric OP-number field on a white strip under the app bar. The gradient
/// "Go" button appears only once the field has text.
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
    final ds = context.ds;
    final l10n = context.l10n;
    final hasText = _controller.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(DsSpace.gutter),
      decoration: BoxDecoration(
        color: ds.card,
        border: Border(bottom: BorderSide(color: ds.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DsTextField(
              controller: _controller,
              mono: true,
              hint: l10n.homeSearchPlaceholder,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 7,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              prefix: const Icon(Icons.search, size: 20),
              suffix: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _controller.clear,
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: DsSpace.x2),
            DsButton.primary(label: l10n.homeGo, expand: false, height: 40, onPressed: _submit),
          ],
        ],
      ),
    );
  }
}

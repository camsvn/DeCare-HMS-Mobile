import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/server_config/application/server_config_controller.dart';

class ConfigureUrlScreen extends ConsumerStatefulWidget {
  const ConfigureUrlScreen({super.key});

  @override
  ConsumerState<ConfigureUrlScreen> createState() => _ConfigureUrlScreenState();
}

class _ConfigureUrlScreenState extends ConsumerState<ConfigureUrlScreen> {
  final _controller = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    FocusScope.of(context).unfocus();
    ref.read(serverConfigControllerProvider.notifier).connect(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(serverConfigControllerProvider, (prev, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        final error = next.error;
        if (error is InvalidServerUrlException) {
          setState(() => _fieldError = l10n.configureUrlInvalidField);
          showDsBanner(context, l10n.configureUrlInvalid, kind: DsBannerKind.warning);
        } else if (error is ApiFailure) {
          showDsBanner(context, l10n.configureUrlHostError(error.describe(l10n)), kind: DsBannerKind.danger);
        }
        return;
      }
      // A connect that just finished successfully: continue to login (the
      // redirect gate sends a still-valid session on to home). Keyed on the
      // loading-to-data transition, not on the value changing, so re-entering
      // the URL that is already saved still moves the user on.
      if (prev != null && prev.isLoading && next.hasValue && next.value != null) {
        context.go(RoutePaths.login);
      }
    });
    final connecting = ref.watch(serverConfigControllerProvider).isLoading;

    return ExitOnDoubleBack(
      child: DsOnboardingScaffold(
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.configureUrlHeading, style: context.dsType.heading),
            const SizedBox(height: DsSpace.x1),
            Text(l10n.configureUrlBody, style: context.dsType.body.withColor(context.ds.textSecondary)),
            const SizedBox(height: DsSpace.x5),
            DsTextField(
              controller: _controller,
              hint: l10n.configureUrlPlaceholder,
              errorText: _fieldError,
              prefix: const Icon(Icons.link, size: 20),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onChanged: (_) => setState(() => _fieldError = null),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: DsSpace.x4),
            DsButton.primary(label: l10n.configureUrlConnect, loading: connecting, onPressed: _connect),
          ],
        ),
      ),
    );
  }
}

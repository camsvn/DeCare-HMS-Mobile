import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/server_config/application/server_config_controller.dart';

class ConfigureUrlScreen extends ConsumerStatefulWidget {
  const ConfigureUrlScreen({super.key});

  @override
  ConsumerState<ConfigureUrlScreen> createState() => _ConfigureUrlScreenState();
}

class _ConfigureUrlScreenState extends ConsumerState<ConfigureUrlScreen> {
  final _controller = TextEditingController();

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
          showFlash(context, l10n.configureUrlInvalid, type: FlashType.warning);
        } else if (error is ApiFailure) {
          showFlash(context, l10n.configureUrlHostError(error.describe(l10n)), type: FlashType.danger);
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
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Image.asset('assets/images/installation_url.png', height: 220, fit: BoxFit.contain),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.configureUrlTitle, style: AppTextStyles.header, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.configureUrlBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _controller,
                  hint: l10n.configureUrlPlaceholder,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: l10n.configureUrlConnect, loading: connecting, onPressed: _connect),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

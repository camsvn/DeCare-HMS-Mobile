import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/application/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    FocusScope.of(context).unfocus();
    ref.read(sessionControllerProvider.notifier).login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(sessionControllerProvider, (prev, next) {
      if (next.isLoading) return;
      final error = next.error;
      if (next.hasError && error is ApiFailure) {
        final text = (error is UnauthorizedFailure || error is NotFoundFailure)
            ? l10n.errorInvalidCredentials
            : error.describe(l10n);
        showFlash(context, l10n.loginError(text), type: FlashType.danger);
      } else if (next.hasValue && next.value != null && prev?.value == null) {
        _username.clear();
        _password.clear();
      }
    });
    final signingIn = ref.watch(sessionControllerProvider).isLoading;

    return ExitOnDoubleBack(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset('assets/images/hms_circle.svg', width: 60, height: 60),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.appTitle, style: AppTextStyles.brandLarge),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  controller: _username,
                  label: l10n.loginUsername,
                  textInputAction: TextInputAction.next,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _password,
                  label: l10n.loginPassword,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.searchBorder,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: l10n.loginSignIn, loading: signingIn, onPressed: _signIn),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: LinkButton(
                    label: l10n.loginChangeUrl,
                    color: AppColors.dim,
                    onPressed: () => context.push(RoutePaths.configure),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

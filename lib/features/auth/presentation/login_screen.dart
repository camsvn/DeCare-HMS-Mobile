import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/application/session_controller.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

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
        showDsBanner(context, l10n.loginError(text), kind: DsBannerKind.danger);
      } else if (next.hasValue && next.value != null && prev?.value == null) {
        _username.clear();
        _password.clear();
      }
    });
    final signingIn = ref.watch(sessionControllerProvider).isLoading;
    final host = Uri.tryParse(ref.watch(serverConfigControllerProvider).valueOrNull ?? '')?.host ?? '';

    return ExitOnDoubleBack(
      child: DsOnboardingScaffold(
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (host.isNotEmpty) ...[
              Align(alignment: Alignment.centerLeft, child: DsChip(text: host, mono: true)),
              const SizedBox(height: DsSpace.x3),
            ],
            Text(l10n.loginHeading, style: context.dsType.heading),
            const SizedBox(height: DsSpace.x5),
            DsTextField(
              controller: _username,
              label: l10n.loginUsername,
              textInputAction: TextInputAction.next,
              autofocus: false,
            ),
            const SizedBox(height: DsSpace.x4),
            DsTextField(
              controller: _password,
              label: l10n.loginPassword,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: DsSpace.x5),
            DsButton.primary(label: l10n.loginSignIn, loading: signingIn, onPressed: _signIn),
            const SizedBox(height: DsSpace.x3),
            Center(
              child: DsButton.ghost(label: l10n.loginChangeUrl, onPressed: () => context.push(RoutePaths.configure)),
            ),
          ],
        ),
      ),
    );
  }
}

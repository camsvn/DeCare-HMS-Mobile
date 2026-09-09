import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/app/session_expiry_listener.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

/// The React Native app painted the status bar in the primary colour on
/// every screen; no screen here uses an AppBar, so set it once for the app.
final SystemUiOverlayStyle appOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: DsColors.light.shell,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class HmsApp extends ConsumerWidget {
  const HmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildDsTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SessionExpiryListener(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: appOverlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      debugShowCheckedModeBanner: false,
    );
  }
}

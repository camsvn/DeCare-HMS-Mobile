import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/app/session_expiry_listener.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/features/settings/settings.dart';

/// The React Native app painted the status bar in the primary colour on
/// every screen; no screen here uses an AppBar, so set it once for the app.
/// The shell is dark in both palettes, so only its colour changes with
/// [brightness] — the icons stay light either way.
SystemUiOverlayStyle appOverlayStyle(Brightness brightness) => SystemUiOverlayStyle(
      statusBarColor: DsColors.of(brightness).shell,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

class HmsApp extends ConsumerWidget {
  const HmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appearanceProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildDsTheme(Brightness.light),
      darkTheme: buildDsTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SessionExpiryListener(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: appOverlayStyle(switch (themeMode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => MediaQuery.platformBrightnessOf(context),
          }),
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

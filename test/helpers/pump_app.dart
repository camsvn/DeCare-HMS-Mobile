import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  ThemeMode themeMode = ThemeMode.light,
}) async {
  // The banner queue is a singleton; drop anything a previous test left in it.
  resetDsBannersForTest();
  await tester.pumpWidget(
    ProviderScope(
      retry: noRetry,
      overrides: overrides,
      child: MaterialApp(
        theme: buildDsTheme(Brightness.light),
        darkTheme: buildDsTheme(Brightness.dark),
        themeMode: themeMode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    ),
  );
}

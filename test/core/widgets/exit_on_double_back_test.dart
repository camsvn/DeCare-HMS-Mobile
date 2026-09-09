import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';

void main() {
  testWidgets('first back shows flash, second within window exits', (tester) async {
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ExitOnDoubleBack(exit: () => exits++, child: const Scaffold(body: Text('home'))),
    ));
    final dynamic state = tester.state(find.byType(ExitOnDoubleBack));
    state.handleBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('App: Press back again to exit'), findsOneWidget);
    expect(exits, 0);
    state.handleBack();
    expect(exits, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('second back after window does not exit', (tester) async {
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ExitOnDoubleBack(
        exit: () => exits++,
        window: const Duration(milliseconds: 100),
        child: const Scaffold(body: Text('home')),
      ),
    ));
    final dynamic state = tester.state(find.byType(ExitOnDoubleBack));
    state.handleBack();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    state.handleBack();
    expect(exits, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a pushed route pops instead of arming the exit', (tester) async {
    var exits = 0;
    Widget guard(String label) => ExitOnDoubleBack(
          exit: () => exits++,
          child: Scaffold(body: Text(label)),
        );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      routes: {
        '/': (_) => guard('first'),
        '/second': (_) => guard('second'),
      },
    ));
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/second');
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('App: Press back again to exit'), findsNothing);
    expect(exits, 0);
  });
}

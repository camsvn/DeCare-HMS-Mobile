import 'package:flutter/widgets.dart';

/// The key on the router's own [Navigator].
///
/// It lives in `core` because features need it too: a full-screen route (the
/// capture screen) declares it as its `parentNavigatorKey` so the page covers
/// the tab bar, and features may not import `lib/app/`. `lib/app/router.dart`
/// re-exports it for callers that already read it from there.
final rootNavigatorKey = GlobalKey<NavigatorState>();

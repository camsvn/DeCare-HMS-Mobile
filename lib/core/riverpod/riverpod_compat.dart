import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 3 retries a provider whose `build` threw, with back-off. Every
/// error state in this app has its own retry affordance (banner, button, the
/// offline queue), so automatic retries would only make the UI flicker
/// between error and loading. Passed as `retry:` to every container/scope.
Duration? noRetry(int retryCount, Object error) => null;

extension AsyncValueKeepPrevious<T> on AsyncValue<T> {
  /// Riverpod 3 made `copyWithPrevious` internal without a public way to say
  /// "loading (or failed), but keep showing the data we had". Controllers
  /// that start an operation from a method (login, connect, search, the upload
  /// queue) need exactly that, so the internal call is confined to this one
  /// place. Revisit when Riverpod 4 offers a public transition API.
  AsyncValue<T> keepingPrevious(AsyncValue<T> previous) =>
      // ignore: invalid_use_of_internal_member
      copyWithPrevious(previous);
}

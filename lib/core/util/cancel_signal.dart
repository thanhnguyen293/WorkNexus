import 'dart:async';

/// A one-shot "stop" signal a caller hands down to work it may abandon — e.g. a
/// board's page fetches once the user opens another board. Pure Dart, so domain
/// and presentation can cancel without knowing the HTTP client; the data layer
/// turns it into its own cancellation (a dio `CancelToken`).
class CancelSignal {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes once [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

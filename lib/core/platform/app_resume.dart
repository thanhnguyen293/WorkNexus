import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the times the user comes back to the app (on desktop, the window
/// regaining focus), so on-screen data fetched elsewhere — e.g. a merge
/// request just merged in the browser — can refresh then.
class AppResumeCounter extends Notifier<int> {
  /// Flipping between windows should not refetch every time.
  static const _minGap = Duration(seconds: 10);

  DateTime? _last;

  @override
  int build() {
    final listener = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(listener.dispose);
    return 0;
  }

  void _onResume() {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < _minGap) return;
    _last = now;
    state++;
  }
}

final appResumeProvider = NotifierProvider<AppResumeCounter, int>(
  AppResumeCounter.new,
);

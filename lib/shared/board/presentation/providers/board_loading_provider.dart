import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Brief skeleton state on first load and workspace switches (design parity).
///
/// Its own file so `filter_providers.dart` can pulse it without importing
/// `board_providers.dart`, which re-exports the filter providers — the
/// dependency runs one way.
class BoardLoading extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _schedule();
    return true;
  }

  void pulse() {
    state = true;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 480), () {
      if (ref.mounted) state = false;
    });
  }
}

final boardLoadingProvider = NotifierProvider<BoardLoading, bool>(
  BoardLoading.new,
);

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/media_playback_priority.dart';

/// A playing video holds the network; background transfers wait for it.
void main() {
  test('busy while any hold is kept; idle completes after the last', () async {
    final priority = MediaPlaybackPriority();
    final seen = <bool>[];
    priority.changes.listen(seen.add);
    expect(priority.busy, isFalse);

    final a = priority.hold();
    final b = priority.hold();
    var idle = false;
    unawaited(priority.idle().then((_) => idle = true));
    a();
    a(); // twice is harmless
    await Future<void>.delayed(Duration.zero);
    expect(priority.busy, isTrue);
    expect(idle, isFalse);

    b();
    await Future<void>.delayed(Duration.zero);
    expect(priority.busy, isFalse);
    expect(idle, isTrue);
    expect(seen, [true, false]);
  });
}

import 'dart:async';

/// Who gets the network first: a video playing on screen that still has to
/// load, over videos cached in the background (a ticket's precache, the
/// files downloaded for preview frames, chat's auto-downloads).
///
/// A playing player [hold]s it while it loads; background transfers wait
/// for [idle] before they start and pause while it is [busy], so the video
/// being watched never stalls behind one nobody is watching.
class MediaPlaybackPriority {
  int _holds = 0;
  final _changes = StreamController<bool>.broadcast(sync: true);

  /// Whether a playing video is loading.
  bool get busy => _holds > 0;

  /// [busy] each time it changes.
  Stream<bool> get changes => _changes.stream;

  /// Marks a playing video as loading until the returned callback is called
  /// (more than once is harmless).
  void Function() hold() {
    if (_holds++ == 0) _changes.add(true);
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (--_holds == 0) _changes.add(false);
    };
  }

  /// Completes once no playing video is loading.
  Future<void> idle() =>
      busy ? changes.firstWhere((b) => !b) : Future<void>.value();
}

/// The app's one [MediaPlaybackPriority], shared by every player and every
/// background video transfer.
final mediaPlaybackPriority = MediaPlaybackPriority();

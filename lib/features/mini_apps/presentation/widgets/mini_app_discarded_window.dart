import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Takes the window a page asked for and closes it at once, for a link the
/// app has already opened somewhere else. Turning the window down is no way
/// out: the web view then loads the link in the asking page itself (Windows
/// and macOS alike), so the window is claimed by an invisible web view that
/// goes as soon as it exists.
class MiniAppDiscardedWindow extends StatelessWidget {
  const MiniAppDiscardedWindow({
    super.key,
    required this.windowId,
    required this.onClaimed,
  });

  final int windowId;
  final VoidCallback onClaimed;

  /// Claims and closes window [windowId] from an overlay over [context].
  static void discard(BuildContext context, int windowId) {
    late final OverlayEntry entry;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry
        ..remove()
        ..dispose();
    }

    entry = OverlayEntry(
      builder: (_) =>
          MiniAppDiscardedWindow(windowId: windowId, onClaimed: remove),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    // A pixel, not zero: a web view laid out with no size may never be made.
    return Positioned(
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: InAppWebView(
            windowId: windowId,
            onWebViewCreated: (_) => onClaimed(),
          ),
        ),
      ),
    );
  }
}

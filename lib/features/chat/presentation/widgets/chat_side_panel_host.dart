import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import 'chat_layout.dart';

/// How much the messages are dimmed under a panel drawn over them.
const double _kScrimAlpha = 0.18;

/// How far (of its width) a panel beside the messages slides as it fades in.
const double _kBesideSlide = 0.08;

/// The open chat with a panel (thread, info, pinned messages, files): beside
/// the messages when they keep their minimum width, else slid over them from
/// the right — squeezing them would wrap text a few letters per line. Over
/// the messages, a click outside the panel calls [onDismiss].
///
/// A panel opening slides in, and closing slides out before it goes. Beside
/// the messages it takes its room at once and only its contents move, so the
/// messages are laid out once, not on every frame of the slide.
class ChatSidePanelHost extends StatefulWidget {
  const ChatSidePanelHost({
    super.key,
    required this.messages,
    required this.panel,
    required this.onDismiss,
  });

  final Widget messages;

  /// Null when no panel is open.
  final Widget? panel;
  final VoidCallback onDismiss;

  @override
  State<ChatSidePanelHost> createState() => _ChatSidePanelHostState();
}

class _ChatSidePanelHostState extends State<ChatSidePanelHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      reverseDuration: AppMotion.base,
      value: widget.panel == null ? 0 : 1,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
  }

  /// The panel on screen: the open one, or the one sliding out.
  late Widget? _shown = widget.panel;

  @override
  void didUpdateWidget(ChatSidePanelHost old) {
    super.didUpdateWidget(old);
    final panel = widget.panel;
    if (panel != null) {
      _shown = panel;
      if (old.panel == null) _run(_controller.forward);
    } else if (old.panel != null) {
      _run(_controller.reverse).whenComplete(() {
        // Gone only if it was not opened again meanwhile.
        if (mounted && widget.panel == null) setState(() => _shown = null);
      });
    }
  }

  /// Plays [step], or jumps to its end when the user asked for less motion.
  TickerFuture _run(TickerFuture Function() step) {
    if (!AppMotion.reduced(context)) return step();
    _controller.value = widget.panel == null ? 0 : 1;
    return TickerFuture.complete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = _shown;
    final closing = widget.panel == null;
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    // [messages] stays the first child whether or not a panel is open: moved
    // in the tree, the message list would be rebuilt from scratch — losing
    // its scroll position and any jump it is making.
    if (infoRoom) {
      return Row(
        children: [
          Expanded(child: widget.messages),
          // Slid toward the window's edge, so nothing needs clipping.
          if (panel != null)
            SlideTransition(
              position: Tween(
                begin: const Offset(_kBesideSlide, 0),
                end: Offset.zero,
              ).animate(_curve),
              child: FadeTransition(opacity: _curve, child: panel),
            ),
        ],
      );
    }
    final c = context.colors;
    return Stack(
      children: [
        widget.messages,
        if (panel != null) ...[
          Positioned.fill(
            // Sliding out, it no longer takes clicks meant for the messages.
            child: IgnorePointer(
              ignoring: closing,
              child: FadeTransition(
                opacity: _curve,
                child: ModalBarrier(
                  color: c.scrim.withValues(alpha: _kScrimAlpha),
                  onDismiss: widget.onDismiss,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(_curve),
              child: IgnorePointer(
                ignoring: closing,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: c.scrim.withValues(alpha: _kScrimAlpha),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: panel,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../providers/chat_providers.dart';
import 'chat_mention_list.dart';
import 'mention_autocomplete.dart';

/// Floats the @mention suggestions as a card just above the composer
/// ([child]) while a mention is being typed in it.
class ChatMentionOverlay extends StatefulWidget {
  const ChatMentionOverlay({
    super.key,
    required this.thread,
    required this.mentions,
    required this.focus,
    required this.onPick,
    required this.child,
  });

  final ChatThreadKey thread;
  final MentionAutocomplete mentions;
  final FocusNode focus;
  final void Function(MentionCandidate candidate) onPick;
  final Widget child;

  @override
  State<ChatMentionOverlay> createState() => _ChatMentionOverlayState();
}

class _ChatMentionOverlayState extends State<ChatMentionOverlay> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    widget.mentions.addListener(_sync);
    widget.focus.addListener(_sync);
  }

  @override
  void dispose() {
    widget.mentions.removeListener(_sync);
    widget.focus.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final show = widget.mentions.query != null && widget.focus.hasFocus;
    if (show == _portal.isShowing) return;
    show ? _portal.show() : _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    // Positioned from the composer's layout-time rect (see QuickSettings):
    // nested tooltips need a paint transform during layout.
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final anchor = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        return Stack(
          children: [
            Positioned(
              left: anchor.left,
              width: math.min(anchor.width, context.spacing.xl6 * 9.5),
              bottom: info.overlaySize.height - anchor.top + context.spacing.sm,
              // Part of the input as far as taps go: clicking a suggestion
              // must not unfocus the field (which would hide the card
              // before the click lands).
              child: TextFieldTapRegion(
                child: ListenableBuilder(
                  listenable: widget.mentions,
                  builder: (context, _) => ChatMentionList(
                    thread: widget.thread,
                    mentions: widget.mentions,
                    onPick: widget.onPick,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

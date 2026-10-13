import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import 'message_body.dart';
import 'message_link_previews.dart';
import 'message_translation_view.dart';

/// What sits inside a text-like bubble: sender name, reply quote, the body,
/// its translation and link previews, then the time on a row of its own.
///
/// With [timeAtEnd] that row is at the bubble's end side, as in Telegram: an
/// invisible copy of [footer] keeps the row's room and the visible one is
/// pinned over it at the end, so the bubble is never wider than its content
/// needs.
class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    super.key,
    required this.accountId,
    required this.message,
    required this.timeAtEnd,
    this.name,
    this.quote,
    this.footer,
  });

  final String accountId;
  final ChatMessage message;
  final bool timeAtEnd;
  final Widget? name;
  final Widget? quote;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final footer = this.footer;
    final pinned = timeAtEnd && footer != null;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name case final name?)
          Padding(
            padding: EdgeInsets.only(bottom: s.xxs),
            child: name,
          ),
        ?quote,
        MessageBody(accountId: accountId, message: message),
        MessageTranslationView(accountId: accountId, gid: message.gid),
        // Compact previews of the links, under the text.
        MessageLinkPreviews(message: message),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: pinned ? _Ghost(footer) : footer,
          ),
      ],
    );
    return pinned ? _Pinned(footer: footer, child: column) : column;
  }
}

/// [child] with [footer] pinned to its bottom-end corner.
class _Pinned extends StatelessWidget {
  const _Pinned({required this.footer, required this.child});

  final Widget footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        PositionedDirectional(end: 0, bottom: 0, child: footer),
      ],
    );
  }
}

/// Keeps [child]'s room without drawing it or taking input.
class _Ghost extends StatelessWidget {
  const _Ghost(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: child,
        ),
      ),
    );
  }
}

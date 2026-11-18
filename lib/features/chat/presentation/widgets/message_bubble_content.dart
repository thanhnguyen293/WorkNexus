import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_privacy_mask.dart';
import 'message_body.dart';
import 'message_fit_cards.dart';
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
    // The bubble stays solid under the faded words, so they leave no hole to
    // the wallpaper. A picture is not faded: its grey cover must show, so
    // only the words around it are.
    final picture = isChatPicture(message.content);
    Widget words(Widget child) =>
        picture ? ChatPrivacyFade(child: child) : child;
    final content = [
      if (name case final name?)
        words(
          Padding(
            padding: EdgeInsets.only(bottom: s.xxs),
            child: name,
          ),
        ),
      if (quote case final quote?) words(quote),
      MessageBody(accountId: accountId, message: message),
      words(MessageTranslationView(accountId: accountId, gid: message.gid)),
    ];
    final footerRow = footer == null
        ? null
        : words(
            Padding(
              padding: EdgeInsets.only(top: s.xs),
              child: pinned ? _Ghost(footer) : footer,
            ),
          );
    // Compact previews of the links, under the text, as wide as the bubble:
    // it is sized to its widest content, and they then take that width.
    final sized = messageHasLinkPreviews(message)
        ? MessageFitCards(
            content: _column(content),
            cards: MessageLinkPreviews(message: message),
            footer: footerRow,
          )
        : _column([...content, ?footerRow]);
    final whole = pinned ? _Pinned(footer: words(footer), child: sized) : sized;
    return picture ? whole : ChatPrivacyFade(child: whole);
  }

  static Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
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

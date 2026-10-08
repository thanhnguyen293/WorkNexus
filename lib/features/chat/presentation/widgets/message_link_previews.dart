import 'package:flutter/material.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../../domain/usecases/parse_merge_request_link.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_labels.dart';
import 'link_preview_card.dart';
import 'merge_request_card.dart';
import 'zentao_ticket_card.dart';

/// Most live link cards (MRs, ZenTao tickets) one message shows.
const int _kMaxLinkCards = 4;

/// Links shown as a live card rather than a page preview.
bool _isCardLink(String url) =>
    const ParseMergeRequestLink()(url) != null ||
    FindLinkedTicket.parse(url) != null;

/// The web addresses a message's previews are for: those in its text, or
/// the shared link itself.
List<String> _previewUrls(ChatMessage message) => switch (message.content) {
  _ when message.deleted => const [],
  TextContent(:final text) => chatUrls(text),
  LinkContent(:final url) => [url],
  _ => const [],
};

/// In a message's bubble, under its text: a compact live card for each
/// merge request and ZenTao ticket it links (a few at most), then a preview
/// of the first other web page. The links themselves stay in the text.
class MessageLinkPreviews extends StatelessWidget {
  const MessageLinkPreviews({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final urls = _previewUrls(message);
    if (urls.isEmpty) return const SizedBox.shrink();
    final cards = urls.where(_isCardLink).take(_kMaxLinkCards);
    final page = urls.where((u) => !_isCardLink(u)).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final url in cards)
          const ParseMergeRequestLink()(url) != null
              ? MergeRequestCard(url: url)
              : ZenTaoTicketCard(url: url),
        if (page != null) LinkPreviewCard(url: page),
      ],
    );
  }
}

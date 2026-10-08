import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_links.dart';

/// Plain message text: `[@Name](@#id)` mentions as highlighted `@Name`, and
/// web addresses as tappable links. Colours and size follow the bubble.
class MentionText extends ConsumerStatefulWidget {
  const MentionText(this.text, {super.key});

  final String text;

  @override
  ConsumerState<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends ConsumerState<MentionText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final ink = ChatBubbleTheme.of(context);
    final base = TextStyle(
      fontSize: ink.fontSize,
      height: 1.45,
      color: ink.text,
    );
    final mention = base.copyWith(color: ink.link, fontWeight: FontWeight.w600);
    final link = base.copyWith(
      color: ink.link,
      decoration: TextDecoration.underline,
      decorationColor: ink.link,
    );
    final text = widget.text;
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in chatTokenPattern.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final name = m.namedGroup('mention');
      if (name != null) {
        spans.add(TextSpan(text: '@$name', style: mention));
      } else {
        final url = m[0]!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => openChatLink(ref, url);
        _recognizers.add(recognizer);
        spans.add(TextSpan(text: url, style: link, recognizer: recognizer));
      }
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}

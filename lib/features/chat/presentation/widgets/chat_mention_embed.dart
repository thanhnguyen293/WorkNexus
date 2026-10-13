import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/app_colors.dart';

/// A mention in the composer: one unit (the caret steps over it, Backspace
/// removes it whole) that carries who is meant, so the message can name them
/// in mention markup however the text around it is edited.
class ChatMentionEmbed extends Embeddable {
  ChatMentionEmbed({required int id, required String name})
    : super(kind, {'id': id, 'name': name});

  static const kind = 'mention';
}

/// Draws a [ChatMentionEmbed] inline as `@Name`, in the accent.
class ChatMentionEmbedBuilder extends EmbedBuilder {
  const ChatMentionEmbedBuilder();

  @override
  String get key => ChatMentionEmbed.kind;

  @override
  bool get expanded => false;

  @override
  String toPlainText(Embed node) => '@${_name(node)}';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Text(
    '@${_name(embedContext.node)}',
    style: embedContext.textStyle.copyWith(
      color: context.colors.accent,
      fontWeight: FontWeight.w600,
    ),
  );

  static String _name(Embed node) => switch (node.value.data) {
    {'name': final String name} => name,
    _ => '',
  };
}

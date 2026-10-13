import 'package:flutter/widgets.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import 'chat_labels.dart';

/// Who is typing, by name: one, two, or the first and a count of the rest.
String chatTypingLabel(
  BuildContext context,
  Map<int, ChatUser> users,
  List<int> typing,
) {
  final l = AppL10n.of(context);
  String name(int id) => chatUserName(context, users, id);
  return switch (typing) {
    [final one] => l.chatTypingOne(name(one)),
    [final first, final second] => l.chatTypingTwo(name(first), name(second)),
    [final first, ...final rest] => l.chatTypingMany(name(first), rest.length),
    [] => '',
  };
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'chat_providers.dart';

/// Unsent text left in a composer: its content as a rich-text delta (each
/// mention an embed, ending in a line break), whether it was typed with
/// Markdown on, and the selection.
typedef ChatComposerDraft = ({
  bool markdown,
  List<Map<String, dynamic>> ops,
  TextSelection selection,
});

/// The text a composer held when it was last closed (null = none), put back
/// when it opens again. A chat's composer is rebuilt on every switch, so its
/// text would otherwise be lost. Kept for the app session, not autoDispose,
/// like the reply draft and staged files beside it.
final chatComposerDraftProvider =
    StateProvider.family<ChatComposerDraft?, ChatComposerKey>(
      (ref, key) => null,
    );

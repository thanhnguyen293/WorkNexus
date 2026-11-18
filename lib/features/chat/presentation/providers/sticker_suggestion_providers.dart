import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/usecases/suggest_reply_stickers.dart';
import '../../domain/usecases/suggest_stickers.dart';
import 'chat_providers.dart';
import 'sticker_providers.dart';

/// Every sticker that can be suggested: the ones tagged with an emoji —
/// none while the user has sticker suggestions turned off.
final _taggedStickersProvider = Provider.autoDispose<List<ChatSticker>>((ref) {
  if (!ref.watch(appSettingsProvider.select((s) => s.chatStickerSuggestions))) {
    return const [];
  }
  final all = ref.watch(chatStickersProvider).value?.valueOrNull ?? const [];
  return [
    for (final s in all)
      if (s.emoji.isNotEmpty) s,
  ];
});

/// What a composer holds, as its sticker suggestions last saw it (set by
/// the suggestion strip as the user types).
final chatStickerDraftProvider = StateProvider.autoDispose
    .family<String, ChatComposerKey>((ref, key) => '');

/// Stickers for what a composer holds.
final chatTypingStickersProvider = Provider.autoDispose
    .family<StickerSuggestions, ChatComposerKey>((ref, key) {
      final draft = ref.watch(chatStickerDraftProvider(key));
      if (draft.trim().isEmpty) return SuggestStickers.none;
      return const SuggestStickers()(draft, ref.watch(_taggedStickersProvider));
    });

/// The newest message of a chat, whatever window its list shows.
final chatLatestMessageProvider = StreamProvider.autoDispose
    .family<ChatMessage?, ChatThreadKey>(
      (ref, key) => ref
          .watch(chatRepositoryProvider)
          .watchMessages(key.accountId, key.chatGid, limit: 1, reactions: false)
          .map((messages) => messages.lastOrNull),
    );

/// The gid of the message whose sticker replies were closed, so they stay
/// closed until another message comes.
final chatReplyStickersDismissedProvider = StateProvider.autoDispose
    .family<String?, ChatThreadKey>((ref, key) => null);

/// Stickers to answer a chat's newest message with; empty once closed.
final chatReplyStickersProvider = Provider.autoDispose
    .family<List<ChatSticker>, ChatThreadKey>((ref, key) {
      final latest = ref.watch(chatLatestMessageProvider(key)).value;
      if (latest == null ||
          ref.watch(chatReplyStickersDismissedProvider(key)) == latest.gid) {
        return const [];
      }
      return const SuggestReplyStickers()(
        latest,
        ref.watch(_taggedStickersProvider),
      );
    });

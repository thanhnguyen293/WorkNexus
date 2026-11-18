import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import '../providers/chat_providers.dart';
import '../providers/sticker_providers.dart';
import '../providers/sticker_suggestion_providers.dart';
import 'chat_composer_controller.dart';
import 'chat_snack.dart';
import 'chat_sticker_image.dart';
import 'chat_suggestion_tray.dart';

/// How long typing settles before the stickers follow it.
const _kSettle = Duration(milliseconds: 200);

/// A strip of stickers over the composer's tools, as messengers show: while
/// typing, stickers for the words or emoji typed (one tap sends it, and
/// clears the draft when the sticker says all of it); with nothing typed,
/// stickers answering the newest message when it is someone else's.
class ChatStickerSuggestionsBar extends ConsumerStatefulWidget {
  const ChatStickerSuggestionsBar({
    super.key,
    required this.draftKey,
    required this.text,
    required this.focus,
    this.threadRootId,
  });

  final ChatComposerKey draftKey;
  final ChatComposerController text;
  final FocusNode focus;

  /// What a sticker answers in a reply thread, unless a message is picked.
  final int? threadRootId;

  @override
  ConsumerState<ChatStickerSuggestionsBar> createState() =>
      _ChatStickerSuggestionsBarState();
}

class _ChatStickerSuggestionsBarState
    extends ConsumerState<ChatStickerSuggestionsBar> {
  Timer? _settle;

  /// The draft the strip was closed for; it comes back once that changes.
  String? _closedFor;

  @override
  void initState() {
    super.initState();
    widget.text.addListener(_typed);
  }

  @override
  void dispose() {
    widget.text.removeListener(_typed);
    _settle?.cancel();
    super.dispose();
  }

  void _typed() {
    _settle?.cancel();
    _settle = Timer(_kSettle, () {
      if (!mounted) return;
      ref.read(chatStickerDraftProvider(widget.draftKey).notifier).state =
          widget.text.plainText;
    });
  }

  Future<void> _send(ChatSticker sticker, {required bool clearDraft}) async {
    final key = widget.draftKey;
    final reply = chatReplyDraftProvider(key);
    final replyToId = ref.read(reply)?.serverId ?? widget.threadRootId;
    ref.read(reply.notifier).state = null;
    if (clearDraft) widget.text.clear();
    widget.focus.requestFocus();
    final result = await ref
        .read(stickerControllerProvider)
        .send(key.chat, sticker, replyToId: replyToId);
    if (result case Err(:final failure) when mounted) {
      showChatFailure(context, failure);
    }
  }

  void _close({required bool typing, required String draft}) {
    if (typing) {
      setState(() => _closedFor = draft);
      return;
    }
    final latest = ref.read(chatLatestMessageProvider(widget.draftKey.chat));
    ref
        .read(chatReplyStickersDismissedProvider(widget.draftKey.chat).notifier)
        .state = latest
        .value
        ?.gid;
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.draftKey;
    final l = AppL10n.of(context);
    final draft = ref.watch(chatStickerDraftProvider(key));
    final typing = draft.trim().isNotEmpty;
    final List<ChatSticker> stickers;
    var clearDraft = false;
    if (typing) {
      final suggestions = ref.watch(chatTypingStickersProvider(key));
      stickers = _closedFor == draft ? const [] : suggestions.stickers;
      clearDraft = suggestions.replacesDraft;
    } else {
      // Replies only under the chat itself, not in a reply thread.
      stickers = key.inThread
          ? const []
          : ref.watch(chatReplyStickersProvider(key.chat));
    }
    if (stickers.isEmpty) return const SizedBox.shrink();
    return _Strip(
      label: typing ? l.chatStickerSuggestions : l.chatStickerReplies,
      stickers: stickers,
      onPick: (sticker) => _send(sticker, clearDraft: typing && clearDraft),
      onClose: () => _close(typing: typing, draft: draft),
    );
  }
}

/// The stickers in a scrolling row, in the suggestion tray.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.label,
    required this.stickers,
    required this.onPick,
    required this.onClose,
  });

  final String label;
  final List<ChatSticker> stickers;
  final ValueChanged<ChatSticker> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final tile = context.sizes.stateTile;
    return ChatSuggestionTray(
      icon: LucideIcons.sticker300,
      label: label,
      closeTooltip: AppL10n.of(context).chatStickerSuggestionsClose,
      onClose: onClose,
      child: SizedBox(
        height: tile + 2 * s.xxs,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: stickers.length,
          separatorBuilder: (_, _) => SizedBox(width: s.sm),
          itemBuilder: (context, i) => _StickerTile(
            sticker: stickers[i],
            size: tile,
            onTap: () => onPick(stickers[i]),
          ),
        ),
      ),
    );
  }
}

/// One suggested sticker; a tap sends it.
class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.sticker,
    required this.size,
    required this.onTap,
  });

  final ChatSticker sticker;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.radii.md);
    return Tooltip(
      message: sticker.emoji,
      child: InkWell(
        borderRadius: radius,
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xxs),
          child: SizedBox.square(
            dimension: size,
            child: ChatStickerImage(sticker: sticker),
          ),
        ),
      ),
    );
  }
}

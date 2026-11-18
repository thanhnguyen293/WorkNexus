import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/opencode_not_linked_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_draft_tone.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_controller.dart';
import 'chat_composer_toolbar.dart';
import 'chat_panels.dart';
import 'chat_snack.dart';

/// The composer's ✨ tool, the one place for the chat's AI help: asks the
/// AI for replies to the latest messages (shown above the input to pick
/// from), rewrites what is typed — clearer, more formal, friendlier or
/// shorter —, opens the chat summary beside the chat, and turns the sticker
/// suggestions over the input on or off.
class ChatAiComposeButton extends ConsumerWidget {
  const ChatAiComposeButton({
    super.key,
    required this.draftKey,
    required this.text,
    required this.focus,
  });

  final ChatComposerKey draftKey;
  final ChatComposerController text;
  final FocusNode focus;

  static const _tones = ChatDraftTone.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    // Watched so the names are loaded by the time a run starts.
    ref.watch(chatAiPeopleProvider(draftKey.chat.accountId));
    final rewriting = ref.watch(chatDraftRewriteProvider(draftKey));
    // The Builder stays while a rewrite runs, only its child changes: its
    // context is the one the rewrite reports back through, so it must stay
    // mounted until the answer comes.
    return Builder(
      builder: (anchor) => rewriting
          ? Tooltip(
              message: l.chatAiRewriting,
              child: SizedBox.square(
                dimension: context.sizes.controlLg,
                child: Center(
                  child: SizedBox.square(
                    dimension: context.sizes.iconMd,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          : ChatComposerToolButton(
              icon: LucideIcons.sparkles300,
              tooltip: l.chatAiTools,
              onPressed: () => _openMenu(anchor, ref),
            ),
    );
  }

  Future<void> _openMenu(BuildContext anchor, WidgetRef ref) async {
    final l = AppL10n.of(anchor);
    final settings = ref.read(appSettingsProvider.notifier);
    final stickersOn = ref.read(appSettingsProvider).chatStickerSuggestions;
    final drafted = !text.isBlank;
    final items = <(AppMenuEntry, Future<void> Function())>[
      (
        AppMenuEntry(
          icon: LucideIcons.messageSquareText300,
          label: l.chatAiSuggestReplies,
        ),
        () => _suggest(anchor, ref),
      ),
      // Rewriting needs something typed.
      if (drafted)
        for (final (i, tone) in _tones.indexed)
          (
            AppMenuEntry(
              icon: LucideIcons.wandSparkles300,
              label: _toneLabel(l, tone),
              dividerBefore: i == 0,
            ),
            () => _rewrite(anchor, ref, tone),
          ),
      // The summary is of the chat itself, not of a reply thread.
      if (!draftKey.inThread)
        (
          AppMenuEntry(
            icon: LucideIcons.scrollText300,
            label: l.chatAiOpenAssistant,
            dividerBefore: true,
          ),
          () async =>
              openChatSidePanel(ref, draftKey.chat, ChatSidePanel.assistant),
        ),
      (
        AppMenuEntry(
          icon: LucideIcons.sticker300,
          label: l.chatStickerSuggestionsSetting,
          checked: stickersOn,
          dividerBefore: draftKey.inThread,
        ),
        () async => settings.setChatStickerSuggestions(!stickersOn),
      ),
    ];
    final box = anchor.findRenderObject() as RenderBox?;
    final at = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final picked = await showAppContextMenu(
      anchor,
      at: at,
      entries: [for (final (entry, _) in items) entry],
    );
    if (picked == null || !anchor.mounted) return;
    await items[picked].$2();
  }

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final people = ref.read(chatAiPeopleProvider(draftKey.chat.accountId));
    final suggestions = ref.read(
      chatReplySuggestionsProvider(draftKey).notifier,
    );
    if (!await ensureOpenCodeLinked(context, ref)) return;
    await suggestions.suggest(people);
  }

  Future<void> _rewrite(
    BuildContext context,
    WidgetRef ref,
    ChatDraftTone tone,
  ) async {
    final l = AppL10n.of(context);
    if (text.hasMentions) {
      showChatSnack(context, l.chatAiRewriteNoMentions);
      return;
    }
    final draft = text.plainText;
    if (draft.trim().isEmpty) {
      showChatSnack(context, l.chatAiRewriteNeedsDraft);
      return;
    }
    final people = ref.read(chatAiPeopleProvider(draftKey.chat.accountId));
    final rewriter = ref.read(chatDraftRewriteProvider(draftKey).notifier);
    if (!await ensureOpenCodeLinked(context, ref)) return;
    final result = await rewriter.rewrite(draft, tone: tone, people: people);
    if (!context.mounted) return;
    switch (result) {
      // Only when the draft is still what was sent: typing meanwhile wins.
      case Ok(:final value) when text.plainText == draft:
        text
          ..clear()
          ..insertText(value);
        focus.requestFocus();
      case Ok():
        break;
      case Err(:final failure):
        showChatSnack(context, l.chatAiFailed(failure.message));
    }
  }

  static String _toneLabel(AppL10n l, ChatDraftTone tone) => switch (tone) {
    ChatDraftTone.clearer => l.chatAiRewriteClearer,
    ChatDraftTone.formal => l.chatAiRewriteFormal,
    ChatDraftTone.friendly => l.chatAiRewriteFriendly,
    ChatDraftTone.shorter => l.chatAiRewriteShorter,
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_controller.dart';
import 'chat_suggestion_tray.dart';

/// Replies the AI suggested, in a tray above the composer's tools. Picking one puts it
/// in the input to edit before sending — never sends it.
class ChatReplySuggestionsBar extends ConsumerWidget {
  const ChatReplySuggestionsBar({
    super.key,
    required this.draftKey,
    required this.text,
    required this.focus,
  });

  final ChatComposerKey draftKey;
  final ChatComposerController text;
  final FocusNode focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatReplySuggestionsProvider(draftKey));
    if (state == null) return const SizedBox.shrink();
    final s = context.spacing;
    final l = AppL10n.of(context);
    final suggestions = ref.read(
      chatReplySuggestionsProvider(draftKey).notifier,
    );
    return ChatSuggestionTray(
      icon: LucideIcons.sparkles300,
      label: switch (state) {
        AsyncData() => l.chatAiSuggestionHint,
        AsyncError(:final error) => l.chatAiFailed('$error'),
        _ => l.chatAiSuggesting,
      },
      isError: state is AsyncError,
      closeTooltip: l.close,
      onClose: suggestions.clear,
      child: switch (state) {
        // Wrapped, not one clipped row: each reply has to be read whole.
        AsyncData(:final value) => Wrap(
          spacing: s.sm,
          runSpacing: s.sm,
          children: [
            for (final reply in value)
              _SuggestionChip(
                reply: reply,
                onPick: () {
                  text
                    ..clear()
                    ..insertText(reply);
                  suggestions.clear();
                  focus.requestFocus();
                },
              ),
          ],
        ),
        _ => null,
      },
    );
  }
}

/// One suggested reply.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.reply, required this.onPick});

  final String reply;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.xl);
    return Material(
      color: c.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: radius,
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPick,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
          child: Text(
            reply,
            style: context.typography.bodySm.copyWith(color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}

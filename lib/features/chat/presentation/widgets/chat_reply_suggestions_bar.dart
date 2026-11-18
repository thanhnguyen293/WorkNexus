import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_controller.dart';

/// Replies the AI suggested, above the composer's tools. Picking one puts it
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
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final suggestions = ref.read(
      chatReplySuggestionsProvider(draftKey).notifier,
    );
    final caption = context.typography.caption.copyWith(color: c.textSecondary);
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Icon(
              LucideIcons.sparkles300,
              size: context.sizes.iconSm,
              color: c.accent,
            ),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: switch (state) {
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.chatAiSuggestionHint, style: caption),
                  SizedBox(height: s.sm),
                  Wrap(
                    spacing: s.md,
                    runSpacing: s.md,
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
                ],
              ),
              AsyncError(:final error) => Text(
                l.chatAiFailed('$error'),
                style: caption.copyWith(color: c.error),
              ),
              _ => Text(l.chatAiSuggesting, style: caption),
            },
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: l.close,
            size: AppIconButtonSize.small,
            onPressed: suggestions.clear,
          ),
        ],
      ),
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
    final radius = BorderRadius.circular(context.radii.lg);
    return Material(
      color: c.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onPick,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
          child: Text(
            reply,
            style: context.typography.body.copyWith(color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}

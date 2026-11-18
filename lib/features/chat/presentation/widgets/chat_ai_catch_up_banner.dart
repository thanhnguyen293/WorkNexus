import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_ai_actions.dart';

/// A strip over the messages of a chat opened with many unread ones,
/// offering an AI summary of them. Gone once dismissed or once the summary
/// is asked for, until the chat is opened again.
class ChatAiCatchUpBanner extends ConsumerWidget {
  const ChatAiCatchUpBanner({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched for as long as the chat is open, so the names are loaded by
    // the time a summary starts.
    ref.watch(chatAiPeopleProvider(thread.accountId));
    if (!ref.watch(chatOffersCatchUpProvider(thread))) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final unread = ref.watch(chatUnreadOnOpenProvider(thread));
    void dismiss() =>
        ref.read(chatCatchUpDismissedProvider(thread).notifier).state = true;
    return Container(
      padding: EdgeInsets.fromLTRB(s.xl3, s.md, s.md, s.md),
      decoration: BoxDecoration(
        color: c.mixT(c.accent, 0.08),
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.sparkles300,
            size: context.sizes.iconMd,
            color: c.accent,
          ),
          SizedBox(width: s.lg),
          Expanded(
            child: Text(
              l.chatAiCatchUp(unread),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(width: s.md),
          AppButton.filled(
            size: AppButtonSize.small,
            icon: LucideIcons.sparkles300,
            onPressed: () => summarizeChat(context, ref, thread, (
              unread: true,
              count: unread,
            ), onStart: dismiss),
            child: Text(l.chatAiCatchUpAction),
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: l.chatAiDismiss,
            onPressed: dismiss,
          ),
        ],
      ),
    );
  }
}

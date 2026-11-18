import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_ai_actions.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';
import 'chat_summary_view.dart';

/// The latest-message counts offered besides the unread ones.
const _kLatestCounts = [50, 100, 200];

/// The panel beside a chat where the AI summarizes it: pick which messages,
/// then read the overview, key points, decisions, action items and open
/// questions.
class ChatAssistantPanel extends ConsumerWidget {
  const ChatAssistantPanel({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    ref.watch(chatAiPeopleProvider(thread.accountId));
    final summary = ref.watch(chatSummaryProvider(thread));
    final scope = ref.watch(chatSummaryScopeProvider(thread));
    final loading = summary?.isLoading ?? false;
    return ChatSidePanelFrame(
      title: l.chatAiAssistant,
      onClose: () => closeChatSidePanel(ref, thread),
      child: ListView(
        padding: EdgeInsets.all(s.xl3),
        children: [
          Text(
            l.chatAiSummaryIntro,
            style: context.typography.paragraph.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: s.xl3),
          Text(
            l.chatAiScopeLabel,
            style: context.typography.captionStrong.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: s.sm),
          _ScopePicker(thread: thread, scope: scope),
          SizedBox(height: s.xl),
          Row(
            children: [
              AppButton.filled(
                icon: LucideIcons.sparkles300,
                isLoading: loading,
                onPressed: loading
                    ? null
                    : () => summarizeChat(context, ref, thread, scope),
                child: Text(
                  summary?.hasValue ?? false
                      ? l.chatAiRegenerate
                      : l.chatAiSummarize,
                ),
              ),
              if (loading) ...[
                SizedBox(width: s.md),
                AppButton.textNeutral(
                  onPressed: () =>
                      ref.read(chatSummaryProvider(thread).notifier).cancel(),
                  child: Text(l.cancel),
                ),
              ],
            ],
          ),
          SizedBox(height: s.xl3),
          switch (summary) {
            null => const SizedBox.shrink(),
            AsyncLoading() => const _Summarizing(),
            AsyncError(:final error) => AppInlineNote(
              text: l.chatAiFailed('$error'),
              isError: true,
            ),
            AsyncData(:final value) => ChatSummaryView(summary: value),
          },
        ],
      ),
    );
  }
}

/// Unread / latest 50 / 100 / 200.
class _ScopePicker extends ConsumerWidget {
  const _ScopePicker({required this.thread, required this.scope});

  final ChatThreadKey thread;
  final ChatSummaryScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final unread = ref.watch(chatUnreadOnOpenProvider(thread));
    void pick(ChatSummaryScope next) =>
        ref.read(chatSummaryScopeProvider(thread).notifier).state = next;
    return AppSegmentedTabs(
      tabs: [
        if (unread > 0)
          AppSegmentedTab(
            label: l.chatAiScopeUnread,
            count: unread,
            active: scope.unread,
            onTap: () => pick((unread: true, count: unread)),
          ),
        for (final count in _kLatestCounts)
          AppSegmentedTab(
            label: '$count',
            active: !scope.unread && scope.count == count,
            onTap: () => pick((unread: false, count: count)),
          ),
      ],
    );
  }
}

/// What shows while the model writes.
class _Summarizing extends StatelessWidget {
  const _Summarizing();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox.square(
          dimension: context.sizes.iconMd,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: context.spacing.lg),
        Text(
          AppL10n.of(context).chatAiSummarizing,
          style: context.typography.secondary.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

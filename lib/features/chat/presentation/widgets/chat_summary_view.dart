import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_summary.dart';
import 'chat_snack.dart';

/// An AI summary of a chat, section by section; empty sections are left out.
class ChatSummaryView extends StatelessWidget {
  const ChatSummaryView({super.key, required this.summary});

  final ChatSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final model = summary.model;
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.overview.isNotEmpty)
            _Section(
              title: l.chatAiOverview,
              icon: LucideIcons.messageSquareText300,
              children: [
                Text(
                  summary.overview,
                  style: context.typography.paragraph.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          if (summary.keyPoints.isNotEmpty)
            _Section(
              title: l.chatAiKeyPoints,
              icon: LucideIcons.sparkle300,
              children: [for (final p in summary.keyPoints) _Bullet(p)],
            ),
          if (summary.decisions.isNotEmpty)
            _Section(
              title: l.chatAiDecisions,
              icon: LucideIcons.gavel300,
              children: [for (final d in summary.decisions) _Bullet(d)],
            ),
          if (summary.actionItems.isNotEmpty)
            _Section(
              title: l.chatAiActionItems,
              icon: LucideIcons.listChecks300,
              children: [
                for (final item in summary.actionItems) _ActionItem(item),
              ],
            ),
          if (summary.openQuestions.isNotEmpty)
            _Section(
              title: l.chatAiOpenQuestions,
              icon: LucideIcons.circleHelp300,
              children: [for (final q in summary.openQuestions) _Bullet(q)],
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  model == null
                      ? l.chatAiSummaryFooterNoModel(summary.messageCount)
                      : l.chatAiSummaryFooter(summary.messageCount, model),
                  style: context.typography.caption.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
              AppIconButton(
                icon: LucideIcons.copy300,
                tooltip: l.chatAiCopySummary,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: chatSummaryAsText(l, summary)),
                  );
                  showChatSnack(context, l.chatAiSummaryCopied);
                },
              ),
            ],
          ),
          SizedBox(height: s.xs),
          Text(
            l.chatAiNote,
            style: context.typography.captionSm.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// [summary] as plain text, to paste into a ticket or another chat.
String chatSummaryAsText(AppL10n l, ChatSummary summary) {
  final out = StringBuffer();
  void section(String title, Iterable<String> lines) {
    if (lines.isEmpty) return;
    if (out.isNotEmpty) out.writeln();
    out.writeln(title);
    for (final line in lines) {
      out.writeln('- $line');
    }
  }

  if (summary.overview.isNotEmpty) out.writeln(summary.overview);
  section(l.chatAiKeyPoints, summary.keyPoints);
  section(l.chatAiDecisions, summary.decisions);
  section(l.chatAiActionItems, [
    for (final item in summary.actionItems)
      [
        if (item.owner.isNotEmpty) '${item.owner}:',
        item.task,
        if (item.due.isNotEmpty) '(${l.chatAiDue(item.due)})',
      ].join(' '),
  ]);
  section(l.chatAiOpenQuestions, summary.openQuestions);
  return out.toString().trim();
}

/// A titled block of the summary.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: s.xl3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.sizes.iconSm, color: c.accent),
              SizedBox(width: s.sm),
              Text(
                title,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: s.sm),
          ...children,
        ],
      ),
    );
  }
}

/// One point of a list section.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.typography.paragraph.copyWith(color: c.textPrimary);
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style.copyWith(color: c.textTertiary)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// A task, with who is to do it and by when when the chat said.
class _ActionItem extends StatelessWidget {
  const _ActionItem(this.item);

  final ChatActionItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final style = context.typography.paragraph.copyWith(color: c.textPrimary);
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: context.spacing.xxs),
            child: Icon(
              LucideIcons.square300,
              size: context.sizes.iconSm,
              color: c.textTertiary,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (item.owner.isNotEmpty)
                    TextSpan(
                      text: '${item.owner}  ',
                      style: style.copyWith(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: item.task),
                  if (item.due.isNotEmpty)
                    TextSpan(
                      text: '  · ${l.chatAiDue(item.due)}',
                      style: style.copyWith(color: c.warning),
                    ),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

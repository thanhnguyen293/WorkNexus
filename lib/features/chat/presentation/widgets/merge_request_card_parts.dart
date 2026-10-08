import 'package:flutter/material.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_avatar.dart';
import 'chat_bubble_theme.dart';

/// The bottom line of a merge request card: the author (avatar and name),
/// then the change size — lines added and removed, files changed — when
/// known.
class MergeRequestFooter extends StatelessWidget {
  const MergeRequestFooter({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final (
      author,
      avatar,
      added,
      removed,
      files,
    ) = switch (ticket.providerEntity) {
      GitLabItemEntity(
        :final author,
        :final authorAvatarUrl,
        :final additions,
        :final deletions,
        :final changedFiles,
      ) =>
        (author, authorAvatarUrl, additions, deletions, changedFiles),
      GitHubItemEntity(
        :final author,
        :final authorAvatarUrl,
        :final additions,
        :final deletions,
        :final changedFiles,
      ) =>
        (author, authorAvatarUrl, additions, deletions, changedFiles),
      _ => (null, null, null, null, null),
    };
    final stat = context.typography.secondaryStrong;
    return Row(
      children: [
        if (author != null) ...[
          ChatAvatar(name: author, imageUrl: avatar, diameter: s.xl3),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.secondary.copyWith(color: ink.meta),
            ),
          ),
        ] else
          const Spacer(),
        if (added != null && removed != null)
          _Chip(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '+${_count(context, added)}',
                    style: stat.copyWith(color: c.success),
                  ),
                  TextSpan(
                    text: ' −${_count(context, removed)}',
                    style: stat.copyWith(color: c.error),
                  ),
                ],
              ),
            ),
          ),
        if (files != null) ...[
          SizedBox(width: s.sm),
          _Chip(
            child: Text(
              l.chatMrFiles(files),
              style: context.typography.secondary.copyWith(color: ink.meta),
            ),
          ),
        ],
      ],
    );
  }

  /// 1867 → "1,867" in the user's locale.
  static String _count(BuildContext context, int n) =>
      MaterialLocalizations.of(context).formatDecimal(n);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
      decoration: BoxDecoration(
        color: ink.text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: child,
    );
  }
}

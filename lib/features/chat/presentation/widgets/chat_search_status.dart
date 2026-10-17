import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Where the in-thread search stands: "3 of 12", "3 of 100+" or none.
class ChatSearchCounter extends StatelessWidget {
  const ChatSearchCounter({
    super.key,
    required this.count,
    required this.hasMore,
    required this.activeIndex,
  });

  final int count;
  final bool hasMore;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final current = count == 0 ? 0 : activeIndex.clamp(0, count - 1) + 1;
    final text = count == 0
        ? l.chatSearchNoMatches
        : hasMore
        ? l.chatSearchMatchesMore(current, count)
        : l.chatSearchMatches(current, count);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: count == 0 ? c.surfaceSubtle : c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
      child: Text(
        text,
        style: context.typography.secondary.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: count == 0 ? c.textTertiary : c.accent,
        ),
      ),
    );
  }
}

/// Said in place of the matches when the search failed.
class ChatSearchFailedLabel extends StatelessWidget {
  const ChatSearchFailedLabel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
    child: Text(
      message,
      style: context.typography.secondary.copyWith(color: context.colors.error),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../util/activity_action_parts.dart';
import 'timeline_item.dart';

/// "actor action" with the time on the right — the first line of every
/// timeline entry. The actor and any person the action names are highlighted;
/// a changed field's new value is set in the strong weight.
class TimelineHeadline extends ConsumerWidget {
  const TimelineHeadline({
    super.key,
    required this.actor,
    required this.action,
    required this.at,
    this.compact = false,
  });

  final String actor;
  final String action;
  final DateTime at;

  /// An event's line — a step smaller than a comment's, so the conversation
  /// leads and the history recedes.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.typography;
    final base = compact ? t.secondary : t.body;
    final person = base.copyWith(
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
    );
    const lineHeight = 1.4;
    // Centers the first line on the gutter marker beside it.
    final top = (kTimelineGutter - (base.fontSize ?? 13) * lineHeight) / 2;
    return Padding(
      padding: EdgeInsets.only(top: top < 0 ? 0 : top),
      child: Row(
        // Time shares the first line's baseline, whatever their sizes.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base.copyWith(
                  color: c.textSecondary,
                  height: lineHeight,
                ),
                children: [
                  TextSpan(text: actor, style: person),
                  const TextSpan(text: ' '),
                  for (final (text, kind) in activityActionParts(action))
                    TextSpan(
                      text: text,
                      style: switch (kind) {
                        ActivityPartKind.plain => null,
                        ActivityPartKind.user => person.copyWith(
                          color: c.accent,
                        ),
                        ActivityPartKind.value => person,
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Text(
            formatWhen(
              context,
              at,
              format: ref.watch(
                appSettingsProvider.select((s) => s.dateFormat),
              ),
            ),
            style: t.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

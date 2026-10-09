import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/group_notifications_by_day.dart';
import 'notification_card.dart';

/// The notifications under a heading per day, newest first.
class NotificationDayList extends StatelessWidget {
  const NotificationDayList({super.key, required this.days});

  final List<NotificationDay> days;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return ListView(
      padding: EdgeInsets.fromLTRB(s.md, 0, s.md, s.xl),
      children: [
        for (final d in days) ...[
          _DayHeading(d.day, count: d.items.length),
          for (final n in d.items)
            NotificationCard(
              key: ValueKey('${n.accountId}:${n.id}'),
              notification: n,
            ),
        ],
      ],
    );
  }
}

/// "Today 4" — the day (relative when recent) and how many fell on it.
class _DayHeading extends ConsumerWidget {
  const _DayHeading(this.day, {required this.count});

  final DateTime? day;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final format = ref.watch(appSettingsProvider.select((s) => s.dateFormat));
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = switch (day) {
      null => l.notificationsUndated,
      final d when today.difference(d).inDays == 0 => l.notificationsToday,
      final d when today.difference(d).inDays == 1 => l.notificationsYesterday,
      final d => switch (format) {
        DateDisplayFormat.iso => DateFormat('yyyy-MM-dd').format(d),
        DateDisplayFormat.dmy => DateFormat('dd/MM/yyyy').format(d),
        DateDisplayFormat.long => DateFormat.yMMMEd(locale).format(d),
      },
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(s.md, s.xl3, s.md, s.sm),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: t.labelWide.copyWith(color: c.textTertiary),
          ),
          SizedBox(width: s.sm),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: s.sm,
              vertical: s.xxs / 2,
            ),
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.pill),
            ),
            child: Text(
              '$count',
              style: t.captionStrong.copyWith(color: c.textSecondary),
            ),
          ),
          SizedBox(width: s.md),
          Expanded(child: Divider(height: 1, thickness: 1, color: c.border)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
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
    final s = context.spacing;
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
    return AppSectionHeader(
      title: label,
      count: count,
      padding: EdgeInsets.fromLTRB(s.md, s.xl, s.md, s.xs),
    );
  }
}

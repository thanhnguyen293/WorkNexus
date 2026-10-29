import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';

/// Timestamp label: within the last hour → localized "just now" / "x minutes
/// ago"; anything older → a concrete date + 24h time, whose **date part** follows
/// [format] (the app-wide [DateDisplayFormat] preference). Time is always `HH:mm`.
String formatWhen(
  BuildContext context,
  DateTime? t, {
  DateTime? now,
  DateDisplayFormat format = DateDisplayFormat.iso,
}) {
  if (t == null) return '';
  final local = t.toLocal();
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(local);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  return formatDate(context, local, format: format, withTime: true);
}

/// A concrete date in the app-wide [format] (see [DateDisplayFormat]), with
/// [withTime] followed by the 24h time `HH:mm`. Always rendered in user local time.
String formatDate(
  BuildContext context,
  DateTime t, {
  DateDisplayFormat format = DateDisplayFormat.iso,
  bool withTime = false,
}) {
  final local = t.toLocal();
  final date = switch (format) {
    DateDisplayFormat.iso => DateFormat('yyyy-MM-dd').format(local),
    DateDisplayFormat.dmy => DateFormat('dd/MM/yyyy').format(local),
    // Locale-aware: `May 26, 2026` (en) / `26 thg 5, 2026` (vi), with the
    // month names `flutter_localizations` loads for the app's locales.
    DateDisplayFormat.long => DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(local),
  };
  return withTime ? '$date ${DateFormat('HH:mm').format(local)}' : date;
}

/// A compact age for dense rows: "5m ago", "3h ago", "4d ago", then the date.
/// Always computed and rendered in user local time.
String shortWhen(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final local = t.toLocal();
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(local);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.daysAgo(diff.inDays);
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(local);
}

/// Formats a timestamp into 24h `HH:mm` local time.
String formatTime(DateTime? t) {
  if (t == null) return '';
  return DateFormat('HH:mm').format(t.toLocal());
}

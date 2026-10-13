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
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  return formatDate(context, t, format: format, withTime: true);
}

/// A concrete date in the app-wide [format] (see [DateDisplayFormat]), with
/// [withTime] followed by the 24h time `HH:mm`.
String formatDate(
  BuildContext context,
  DateTime t, {
  DateDisplayFormat format = DateDisplayFormat.iso,
  bool withTime = false,
}) {
  final date = switch (format) {
    DateDisplayFormat.iso => DateFormat('yyyy-MM-dd').format(t),
    DateDisplayFormat.dmy => DateFormat('dd/MM/yyyy').format(t),
    // Locale-aware: `May 26, 2026` (en) / `26 thg 5, 2026` (vi), with the
    // month names `flutter_localizations` loads for the app's locales.
    DateDisplayFormat.long => DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(t),
  };
  return withTime ? '$date ${DateFormat('HH:mm').format(t)}' : date;
}

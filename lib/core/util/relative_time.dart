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
  return switch (format) {
    DateDisplayFormat.iso => DateFormat('yyyy-MM-dd HH:mm').format(t),
    DateDisplayFormat.dmy => DateFormat('dd/MM/yyyy HH:mm').format(t),
    DateDisplayFormat.long => _long(context, t),
  };
}

/// Locale-aware long date + 24h time, e.g. `May 26, 2026 10:28` (en) /
/// `26 thg 5, 2026 10:28` (vi). Uses the current locale's month names (loaded by
/// `flutter_localizations` for the app's supported locales).
String _long(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toString();
  final date = DateFormat.yMMMd(locale).format(t);
  final time = DateFormat('HH:mm').format(t);
  return '$date $time';
}

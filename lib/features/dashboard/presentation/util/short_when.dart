import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

/// A compact age for dense rows: "5m ago", "3h ago", "4d ago", then the date.
String shortWhen(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(t.toLocal());
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.daysAgo(diff.inDays);
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(t.toLocal());
}

/// A ZenTao date field (`2026-10-12`), or null for its empty forms
/// (`''`, `0000-00-00`).
DateTime? parseZenTaoDate(String? raw) {
  final d = DateTime.tryParse(raw?.trim() ?? '');
  return d == null || d.year < 2000 ? null : d;
}

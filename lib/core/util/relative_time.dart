import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Timestamp label: within the last hour → localized "just now" / "x minutes
/// ago"; anything older → a concrete "yyyy-MM-dd HH:mm".
String formatWhen(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  return DateFormat('yyyy-MM-dd HH:mm').format(t);
}

part of 'chat_labels.dart';

// Time labels: day separators, list timestamps and relative "ago" times.

/// Day separator label: today / yesterday / a localized date.
String chatDayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l = AppL10n.of(context);
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final d = DateUtils.dateOnly(day);
  if (d == today) return l.chatToday;
  if (d == today.subtract(const Duration(days: 1))) return l.chatYesterday;
  final locale = Localizations.localeOf(context).toString();
  return d.year == today.year
      ? DateFormat.MMMMd(locale).format(d)
      : DateFormat.yMMMMd(locale).format(d);
}

/// Compact time for the chat list: 10:05 today, "Yesterday", a weekday within
/// the week, else a short date.
String chatListTime(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(t);
  final locale = Localizations.localeOf(context).toString();
  final age = today.difference(day).inDays;
  if (age == 0) return DateFormat('HH:mm').format(t);
  if (age == 1) return AppL10n.of(context).chatYesterday;
  if (age < 7) return DateFormat.E(locale).format(t);
  return t.year == today.year
      ? DateFormat('dd/MM').format(t)
      : DateFormat('dd/MM/yy').format(t);
}

/// How long ago [t] was, compactly: "just now", "5m ago", "2h ago", "3d
/// ago", then the date.
String chatAgo(BuildContext context, DateTime t, {DateTime? now}) {
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.daysAgo(diff.inDays);
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(t);
}

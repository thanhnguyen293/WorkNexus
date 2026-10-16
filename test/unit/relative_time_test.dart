import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:work_nexus/core/util/relative_time.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/github/data/mappers/github_normalize.dart';
import 'package:work_nexus/tools/gitlab/data/mappers/gitlab_normalize.dart';
import 'package:work_nexus/tools/zentao/data/mappers/zentao_normalize.dart';

void main() {
  group('relative_time utilities', () {
    testWidgets('formatTime formats UTC date in user local time', (
      tester,
    ) async {
      final utcTime = DateTime.utc(2026, 10, 16, 2, 30);
      final expected = DateFormat('HH:mm').format(utcTime.toLocal());

      expect(formatTime(utcTime), equals(expected));
      expect(formatTime(null), equals(''));
    });

    testWidgets('formatDate formats in local time with ISO and withTime', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(),
        ),
      );
      final context = tester.element(find.byType(Scaffold));

      final utcTime = DateTime.utc(2026, 10, 16, 2, 30);
      final local = utcTime.toLocal();
      final expectedDate = DateFormat('yyyy-MM-dd').format(local);
      final expectedTime = DateFormat('HH:mm').format(local);

      final dateOnly = formatDate(context, utcTime);
      expect(dateOnly, equals(expectedDate));

      final withTime = formatDate(
        context,
        utcTime,
        withTime: true,
      );
      expect(withTime, equals('$expectedDate $expectedTime'));
    });

    testWidgets('formatWhen uses relative time when recent, local time when older', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(),
        ),
      );
      final context = tester.element(find.byType(Scaffold));

      final now = DateTime.now();
      final recent = now.subtract(const Duration(minutes: 5)).toUtc();
      final justNow = now.subtract(const Duration(seconds: 30)).toUtc();
      final older = now.subtract(const Duration(hours: 3)).toUtc();

      expect(formatWhen(context, justNow, now: now), equals('just now'));
      expect(formatWhen(context, recent, now: now), equals('5m ago'));

      final expectedOlder = formatDate(
        context,
        older,
        withTime: true,
      );
      expect(formatWhen(context, older, now: now), equals(expectedOlder));
    });

    testWidgets('shortWhen handles compact ages in local time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(),
        ),
      );
      final context = tester.element(find.byType(Scaffold));

      final now = DateTime.now();
      final justNow = now.subtract(const Duration(seconds: 20)).toUtc();
      final minutesAgo = now.subtract(const Duration(minutes: 15)).toUtc();
      final hoursAgo = now.subtract(const Duration(hours: 4)).toUtc();
      final daysAgo = now.subtract(const Duration(days: 3)).toUtc();
      final weeksAgo = now.subtract(const Duration(days: 10)).toUtc();

      expect(shortWhen(context, justNow, now: now), equals('just now'));
      expect(shortWhen(context, minutesAgo, now: now), equals('15m ago'));
      expect(shortWhen(context, hoursAgo, now: now), equals('4h ago'));
      expect(shortWhen(context, daysAgo, now: now), equals('3d ago'));

      final expectedDate = DateFormat.MMMd(
        Localizations.localeOf(context).toString(),
      ).format(weeksAgo.toLocal());
      expect(shortWhen(context, weeksAgo, now: now), equals(expectedDate));
    });

    test('DateTimeTimezoneX.toUserLocal converts UTC to local', () {
      final utc = DateTime.utc(2026, 10, 16, 2, 30);
      expect(utc.toUserLocal().isUtc, isFalse);
    });
  });

  group('Provider Date Normalization to UTC', () {
    test('parseZenTaoDate parses string and normalizes to UTC', () {
      expect(parseZenTaoDate(null), isNull);
      expect(parseZenTaoDate(''), isNull);
      expect(parseZenTaoDate('0000-00-00 00:00:00'), isNull);

      final date = parseZenTaoDate('2026-10-16 14:30:00');
      expect(date, isNotNull);
      expect(date!.isUtc, isTrue);

      // Verify that when converted back to local, it recovers the input time
      final local = date.toLocal();
      expect(local.year, equals(2026));
      expect(local.month, equals(10));
      expect(local.day, equals(16));
      expect(local.hour, equals(14));
      expect(local.minute, equals(30));
    });

    test('parseGitHubDate normalizes to UTC', () {
      expect(parseGitHubDate(null), isNull);
      expect(parseGitHubDate(''), isNull);

      final date = parseGitHubDate('2026-10-16T02:30:00Z');
      expect(date, isNotNull);
      expect(date!.isUtc, isTrue);
    });

    test('parseGitLabDate normalizes to UTC', () {
      expect(parseGitLabDate(null), isNull);
      expect(parseGitLabDate(''), isNull);

      final date = parseGitLabDate('2026-10-16T02:30:00Z');
      expect(date, isNotNull);
      expect(date!.isUtc, isTrue);
    });
  });
}

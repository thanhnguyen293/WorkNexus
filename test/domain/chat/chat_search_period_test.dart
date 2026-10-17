import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_search_period.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_timeline_extent.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);

  test('a period counts back from now; any time has no bound', () {
    expect(ChatSearchPeriod.all.since(now), isNull);
    expect(ChatSearchPeriod.week.since(now), DateTime(2026, 10, 10, 12));
    expect(ChatSearchPeriod.month.since(now), DateTime(2026, 9, 17, 12));
  });

  group('ChatTimelineExtent.reaches', () {
    final since = DateTime(2026, 10, 10);

    test('a timeline holding the first message reaches any date', () {
      const extent = ChatTimelineExtent(count: 3, reachesStart: true);
      expect(extent.reaches(null), isTrue);
      expect(extent.reaches(since), isTrue);
    });

    test('one going back past the date reaches it', () {
      final extent = ChatTimelineExtent(
        count: 40,
        oldestServerId: 9,
        oldestSentAt: DateTime(2026, 10, 9),
      );
      expect(extent.reaches(since), isTrue);
      expect(extent.reaches(null), isFalse);
    });

    test('one starting after the date does not', () {
      final extent = ChatTimelineExtent(
        count: 40,
        oldestServerId: 9,
        oldestSentAt: DateTime(2026, 10, 12),
      );
      expect(extent.reaches(since), isFalse);
    });
  });
}

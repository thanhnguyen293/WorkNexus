import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_search_period.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_timeline_extent.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_search_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_thread_search_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  const thread = (accountId: 'acc1', chatGid: 'g1');

  final sampleMessages = <ChatMessage>[
    ChatMessage(
      accountId: 'acc1',
      gid: 'msg-1',
      chatGid: 'g1',
      senderId: 101,
      sentAt: DateTime(2026, 10, 13, 10, 30),
      content: const MessageContent.text(
        'Please check the latest documentation release',
      ),
      isMine: false,
      serverId: 1001,
      index: 1,
    ),
    ChatMessage(
      accountId: 'acc1',
      gid: 'msg-2',
      chatGid: 'g1',
      senderId: 102,
      sentAt: DateTime(2026, 10, 13, 11),
      content: const MessageContent.text(
        'Documentation was reviewed by Oliver and approved',
      ),
      isMine: false,
      serverId: 1002,
      index: 2,
    ),
  ];

  Widget buildSearchHarness({
    required Widget child,
    List<ChatMessage> matches = const [],
    Future<ChatSearchResults> Function(Ref ref)? threadMatches,
    ChatRepository? repository,
    VoidCallback? onSearch,
    ChatSearchPeriod period = ChatSearchPeriod.all,
  }) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          chatRepositoryProvider.overrideWithValue(repository),
        chatSearchPeriodProvider('acc1').overrideWith((ref) => period),
        chatThreadSearchMatchesProvider(thread).overrideWith(
          threadMatches ??
              (ref) async {
                onSearch?.call();
                return (messages: matches, hasMore: false);
              },
        ),
        chatConversationsProvider('acc1').overrideWith(
          (ref) => Stream.value([
            ChatConversation(
              accountId: 'acc1',
              gid: 'g1',
              type: ChatType.group,
              name: 'General Discussion',
              lastActiveAt: DateTime.now(),
            ),
          ]),
        ),
        chatUsersProvider('acc1').overrideWith(
          (ref) => Stream.value({
            101: const ChatUser(
              accountId: 'acc1',
              userId: 101,
              account: 'edward_smith',
              realname: 'Edward Smith',
            ),
            102: const ChatUser(
              accountId: 'acc1',
              userId: 102,
              account: 'oliver_brown',
              realname: 'Oliver Brown',
            ),
          }),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: ChatLayoutScope(
            layout: const ChatLayout(compactList: false, infoRoom: true),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'ChatThreadSearchBar shows match counter and steps through matches',
    (tester) async {
      await tester.pumpWidget(
        buildSearchHarness(
          child: const ChatThreadSearchBar(thread: thread),
          matches: sampleMessages,
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);

      // Enter query
      await tester.enterText(input, 'Documentation');
      await tester.pumpAndSettle();

      // Verify counter
      expect(find.text('1 of 2'), findsOneWidget);

      // The first step visits the first match, not the second.
      final nextBtn = find.byTooltip('Next');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Verify index advanced to 2
      expect(find.text('2 of 2'), findsOneWidget);

      // Step previous
      final prevBtn = find.byTooltip('Previous');
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Test repeated Enter key navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
    },
  );

  testWidgets('the time range is picked from the bar for every search', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSearchHarness(
        child: const ChatThreadSearchBar(thread: thread),
        matches: sampleMessages,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Any time'), findsOneWidget);

    await tester.tap(find.text('Any time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past 7 days'));
    await tester.pumpAndSettle();

    expect(find.text('Past 7 days'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatThreadSearchBar)),
    );
    expect(
      container.read(chatSearchPeriodProvider('acc1')),
      ChatSearchPeriod.week,
    );
  });

  ChatMessage olderMatch() => sampleMessages.first.copyWith(
    gid: 'msg-0',
    serverId: 1000,
    index: 0,
    sentAt: DateTime(2026, 10, 12),
  );

  testWidgets('stepping past the last loaded match loads the next page', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSearchHarness(
        child: const ChatThreadSearchBar(thread: thread),
        threadMatches: (ref) async {
          final limit = ref.watch(chatThreadSearchLimitProvider(thread));
          return limit > chatSearchPageSize
              ? (messages: [...sampleMessages, olderMatch()], hasMore: false)
              : (messages: sampleMessages, hasMore: true);
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'doc');
    await tester.pumpAndSettle();
    expect(find.text('1 of 2+'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2+'), findsOneWidget);

    // Past the second: the next page comes in instead of wrapping around.
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
  });

  testWidgets('a failed search says so rather than "No results"', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSearchHarness(
        child: const ChatThreadSearchBar(thread: thread),
        threadMatches: (ref) async => throw const StorageFailure('disk'),
      ),
    );
    await tester.enterText(find.byType(TextField), 'doc');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't search messages"), findsOneWidget);
    expect(find.text('No results'), findsNothing);
  });

  group('older history', () {
    late _Repo repo;
    late Completer<Result<int>> page;

    setUp(() {
      repo = _Repo();
      when(() => repo.timelineExtent(any(), any())).thenAnswer(
        (_) async =>
            const Ok(ChatTimelineExtent(count: 2, oldestServerId: 1001)),
      );
      when(
        () => repo.messageCount(any(), any()),
      ).thenAnswer((_) async => const Ok(120));
      when(
        () => repo.loadOlderMessages(
          any(),
          any(),
          beforeServerId: any(named: 'beforeServerId'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => page.future);
    });

    Future<void> search(
      WidgetTester tester, {
      VoidCallback? onSearch,
      ChatSearchPeriod period = ChatSearchPeriod.all,
    }) async {
      // Made in the test's zone: one made in setUp would complete outside
      // the fake clock the test pumps.
      page = Completer();
      await tester.pumpWidget(
        buildSearchHarness(
          child: const ChatThreadSearchBar(thread: thread),
          repository: repo,
          onSearch: onSearch,
          period: period,
        ),
      );
      await tester.enterText(find.byType(TextField), 'not stored yet');
      // Not settled: back to a date, the progress has no end to show and
      // runs until the page in flight lands.
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    const downloading = 'Downloading older messages…';

    Future<Result<int>> loadOlder() => repo.loadOlderMessages(
      any(),
      any(),
      beforeServerId: any(named: 'beforeServerId'),
      pageSize: any(named: 'pageSize'),
    );

    testWidgets('starts at once while a chat is searched, 200 a page', (
      tester,
    ) async {
      await search(tester);

      expect(find.text('No results'), findsOneWidget);
      expect(find.text(downloading), findsOneWidget);
      expect(find.text('2 of 120'), findsOneWidget);
      verify(
        () => repo.loadOlderMessages(
          'acc1',
          'g1',
          beforeServerId: 1001,
          pageSize: 200,
        ),
      ).called(1);
    });

    testWidgets('asks nothing when the history is already stored', (
      tester,
    ) async {
      when(() => repo.timelineExtent(any(), any())).thenAnswer(
        (_) async => const Ok(
          ChatTimelineExtent(count: 2, oldestServerId: 1, reachesStart: true),
        ),
      );
      await search(tester);
      expect(find.text(downloading), findsNothing);
      verifyNever(loadOlder);
    });

    testWidgets('a time range downloads only back to its start', (
      tester,
    ) async {
      // Stored back 10 days: enough for the past 7 days, not for 30.
      when(() => repo.timelineExtent(any(), any())).thenAnswer(
        (_) async => Ok(
          ChatTimelineExtent(
            count: 2,
            oldestServerId: 1001,
            oldestSentAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
        ),
      );
      await search(tester, period: ChatSearchPeriod.month);
      // A month back is further than what is stored: it downloads.
      expect(find.text(downloading), findsOneWidget);

      // The running download's progress never settles: pump the menu open.
      await tester.tap(find.text('Past 30 days'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Past 7 days').last);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // A week back is stored already: nothing left to download.
      expect(find.text(downloading), findsNothing);
    });

    testWidgets('stopped, it stays stopped until resumed', (tester) async {
      await search(tester);
      await tester.tap(find.byTooltip('Stop loading older messages'));
      await tester.pumpAndSettle();

      expect(find.text(downloading), findsNothing);
      expect(find.text('Stopped loading older messages'), findsOneWidget);
      verify(loadOlder).called(1);

      page = Completer();
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump();
      expect(find.text(downloading), findsOneWidget);
    });

    testWidgets('once downloaded the search runs again', (tester) async {
      var searches = 0;
      await search(tester, onSearch: () => searches++);
      final before = searches;
      page.complete(const Ok(0)); // nothing older: the start
      await tester.pumpAndSettle();

      expect(searches, greaterThan(before));
      expect(find.text(downloading), findsNothing);
    });

    testWidgets('a failed download says so and can be retried', (tester) async {
      await search(tester);
      page.complete(const Err(NetworkFailure('Chat is offline')));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't download older messages"), findsOneWidget);
      page = Completer();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text(downloading), findsOneWidget);
    });
  });
}

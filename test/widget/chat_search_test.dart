import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_global_search_panel.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_thread_search_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

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
  }) {
    return ProviderScope(
      overrides: [
        chatThreadSearchMatchesProvider(
          thread,
        ).overrideWith((ref) async => matches),
        chatGlobalSearchResultsProvider(
          'acc1',
        ).overrideWith((ref) async => matches),
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

  testWidgets('ChatGlobalSearchPanel displays matched messages and tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSearchHarness(
        child: const SizedBox(
          width: 340,
          child: ChatGlobalSearchPanel(thread: thread),
        ),
        matches: sampleMessages,
      ),
    );
    await tester.pumpAndSettle();

    // Check title and filter chips
    expect(find.text('Search chat history'), findsOneWidget);
    expect(find.text('Search all chats'), findsOneWidget);
    expect(find.text('In this chat'), findsOneWidget);

    // Enter search text
    final input = find.byType(TextField);
    await tester.enterText(input, 'documentation');
    await tester.pumpAndSettle();

    // Verify result list contains the messages and match count
    expect(find.text('2 matches found'), findsOneWidget);
    expect(
      find.textContaining('Please check the latest documentation release'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Documentation was reviewed by Oliver and approved'),
      findsOneWidget,
    );

    // Tap first message tile
    await tester.tap(
      find.textContaining('Please check the latest documentation release'),
    );
    await tester.pumpAndSettle();
  });
}

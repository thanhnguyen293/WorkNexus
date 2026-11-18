import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/entities/message_reaction.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_typing_signal.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_bubble.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_list.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// Serves one chat's messages from a stream the test pushes to.
class _Repo extends Fake implements ChatRepository {
  final messages = StreamController<List<ChatMessage>>.broadcast();

  @override
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
    bool reactions = true,
  }) => messages.stream;

  @override
  Stream<List<ChatConversation>> watchConversations(String accountId) =>
      Stream.value(const []);

  @override
  Stream<List<ChatUser>> watchUsers(String accountId) => Stream.value([
    for (var id = 1; id <= 5; id++)
      ChatUser(accountId: 'acc', userId: id, account: 'u$id', realname: 'U$id'),
  ]);

  @override
  Stream<int?> watchSelfUserId(String a) => Stream.value(1);

  @override
  Stream<List<ChatMessage>> watchReplies(String a, String c) =>
      Stream.value(const []);

  @override
  Stream<Map<int, List<MessageReaction>>> watchReactions(String a, String c) =>
      Stream.value(const {});

  @override
  Stream<ChatTypingSignal> watchTyping(String accountId) =>
      const Stream.empty();

  @override
  Future<Result<int>> loadOlderMessages(
    String a,
    String chatGid, {
    int? beforeServerId,
    bool inWindow = false,
    int? pageSize,
  }) async => const Ok(0);

  @override
  Future<Result<void>> markRead(String a, String chatGid) async =>
      const Ok(null);

  @override
  Future<Result<void>> fetchMessages(String a, String c, List<int> ids) async =>
      const Ok(null);
}

final _start = DateTime(2026, 11, 1, 9);

ChatMessage _message(int i) => ChatMessage(
  accountId: 'acc',
  gid: 'm$i',
  serverId: i,
  chatGid: 'g1',
  // Runs of three from one sender, so rows group like a real chat.
  senderId: 1 + (i ~/ 3) % 5,
  isMine: (i ~/ 3) % 5 == 0,
  sentAt: _start.add(Duration(minutes: i)),
  content: MessageContent.text(
    i % 7 == 0
        ? '**Release $i** notes:\n- fixed the build\n- `code` here'
        : 'Message number $i with some words to wrap across the bubble',
  ),
);

/// Every element whose widget is a [T], by element, with its widget now.
Map<Element, Widget> _snapshot<T extends Widget>(WidgetTester tester) => {
  for (final e in tester.allElements)
    if (e.widget is T) e: e.widget,
};

/// How many of the [before] elements got a new widget (were rebuilt by their
/// parent), plus the ones mounted since.
int _rebuilt<T extends Widget>(
  WidgetTester tester,
  Map<Element, Widget> before,
) {
  var n = 0;
  for (final e in tester.allElements) {
    if (e.widget is! T) continue;
    if (!identical(before[e], e.widget)) n++;
  }
  return n;
}

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  Future<void> pumpList(WidgetTester tester, List<ChatMessage> shown) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          chatReactionsOnProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: MessageList(
              thread: (accountId: 'acc', chatGid: 'g1'),
              showSenders: true,
            ),
          ),
        ),
      ),
    );
    repo.messages.add(shown);
    await tester.pumpAndSettle();
  }

  testWidgets('a new message rebuilds only the rows it touches', (
    tester,
  ) async {
    var shown = [for (var i = 0; i < 50; i++) _message(i)];
    await pumpList(tester, shown);
    final mounted = _snapshot<MessageBubble>(tester).length;

    var rebuilt = 0;
    final watch = Stopwatch();
    const rounds = 20;
    for (var r = 0; r < rounds; r++) {
      final before = _snapshot<MessageBubble>(tester);
      shown = [...shown.skip(1), _message(50 + r)];
      repo.messages.add(shown);
      // The stream delivers on a microtask; the rows rebuild the frame after.
      await tester.pump();
      watch.start();
      await tester.pump();
      watch.stop();
      await tester.pumpAndSettle();
      rebuilt += _rebuilt<MessageBubble>(tester, before);
    }
    final perRound = rebuilt / rounds;
    debugPrint(
      'PERF new-message: $mounted bubbles mounted, '
      '${perRound.toStringAsFixed(1)} rebuilt per message, '
      '${(watch.elapsedMicroseconds / rounds / 1000).toStringAsFixed(2)} '
      'ms per frame',
    );
    // The new row, the one before it (its run may end) and the oldest,
    // pushed out — not every row on screen (all of them before).
    expect(perRound, lessThan(4));
  });

  testWidgets('scrolling builds only the rows that come into view', (
    tester,
  ) async {
    await pumpList(tester, [for (var i = 0; i < 50; i++) _message(i)]);
    final list = find.byType(Scrollable).first;
    final before = _snapshot<MessageBubble>(tester);
    final watch = Stopwatch()..start();
    var frames = 0;
    for (var r = 0; r < 30; r++) {
      await tester.drag(list, const Offset(0, 40));
      await tester.pump();
      frames++;
    }
    watch.stop();
    final rebuilt = _rebuilt<MessageBubble>(tester, before);
    debugPrint(
      'PERF scroll: $rebuilt bubble builds over $frames frames, '
      '${(watch.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)} '
      'ms per frame',
    );
    // Only rows scrolling into view are built; the ones on screen are not
    // rebuilt when the jump-to-latest button shows.
    expect(rebuilt, lessThan(25));
  });
}

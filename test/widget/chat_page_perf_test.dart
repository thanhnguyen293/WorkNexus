import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/entities/message_reaction.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_connection_status.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_typing_signal.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/pages/chat_page.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_typing_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_composer_field.dart';
import 'package:work_nexus/features/chat/presentation/widgets/conversation_tile.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/rebuild_counter.dart';

final _start = DateTime(2026, 11, 1, 9);

ChatMessage _message(String chat, int i) => ChatMessage(
  accountId: 'acc',
  gid: '$chat-m$i',
  serverId: i,
  chatGid: chat,
  senderId: 1 + (i ~/ 3) % 5,
  isMine: (i ~/ 3) % 5 == 0,
  sentAt: _start.add(Duration(minutes: i)),
  content: MessageContent.text(
    i % 7 == 0
        ? '**Release $i** notes:\n- fixed the build\n- `code` here'
        : 'Message number $i with some words to wrap across the bubble',
  ),
);

ChatConversation _chat(int i, {int last = 49}) => ChatConversation(
  accountId: 'acc',
  gid: 'g$i',
  type: ChatType.group,
  name: 'Team $i',
  unreadCount: i % 4,
  lastActiveAt: _start.add(Duration(minutes: last, seconds: -i)),
  lastMessage: _message('g$i', last),
);

/// Forty group chats of fifty messages each.
class _Repo extends Fake implements ChatRepository {
  final chats = StreamController<List<ChatConversation>>.broadcast();
  List<ChatConversation> listed = [for (var i = 0; i < 40; i++) _chat(i)];

  @override
  Stream<ChatConnectionStatus> watchStatus(String accountId) =>
      Stream.value(const ChatConnectionStatus.online(selfUserId: 1));

  @override
  Stream<ChatMessage> watchIncoming() => const Stream.empty();

  @override
  Stream<List<ChatConversation>> watchConversations(String accountId) async* {
    yield listed;
    yield* chats.stream;
  }

  @override
  Stream<List<ChatUser>> watchUsers(String accountId) => Stream.value([
    for (var id = 1; id <= 5; id++)
      ChatUser(accountId: 'acc', userId: id, account: 'u$id', realname: 'U$id'),
  ]);

  @override
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
    bool reactions = true,
  }) => Stream.value([for (var i = 0; i < 50; i++) _message(chatGid, i)]);

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
  Stream<List<ChatMessage>> watchAttachments(String a, String c) =>
      Stream.value(const []);

  @override
  Stream<ChatMessage?> watchMessage(String a, String c, int id) =>
      Stream.value(null);

  @override
  Future<Result<void>> refreshMessages(String a, String chatGid) async =>
      const Ok(null);

  @override
  Future<Result<void>> markRead(String a, String chatGid) async =>
      const Ok(null);

  @override
  Future<Result<void>> sendTyping(
    String accountId,
    String chatGid, {
    required bool typing,
  }) async => const Ok(null);

  @override
  Future<Result<int>> loadOlderMessages(
    String a,
    String chatGid, {
    int? beforeServerId,
    bool inWindow = false,
    int? pageSize,
  }) async => const Ok(0);

  @override
  Future<Result<void>> fetchMessages(String a, String c, List<int> ids) async =>
      const Ok(null);

  @override
  Future<Result<List<int>>> members(String a, String c) async =>
      const Ok([1, 2, 3, 4, 5]);

  @override
  Future<Result<int>> memberCount(String a, String c) async => const Ok(5);

  @override
  Future<Result<Map<String, String>>> roleNames(String a) async => const Ok({});

  @override
  Future<Result<int>> messageCount(String a, String chatGid) async =>
      const Ok(50);

  @override
  void setReactions(bool on) {}

  @override
  void setCacheLimit(int bytes) {}

  @override
  void setVideoAutoDownloadLimit(int bytes) {}

  @override
  Future<Result<void>> connect(String accountId) async => const Ok(null);
}

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatOpenProvider.overrideWithValue(true),
          chatRepositoryProvider.overrideWithValue(repo),
          chatTypingClockProvider.overrideWithValue(tester.binding.clock.now),
          chatAccountsProvider.overrideWithValue(const [
            Account(
              id: 'acc',
              workspaceId: 'ws',
              providerType: ProviderType.zentao,
              handle: 'Me',
            ),
          ]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(body: ChatPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('measure the chat page', (tester) async {
    await pumpChat(tester);
    final counter = RebuildCounter(tester);

    // Opening a chat, then switching to another.
    await tester.tap(find.text('Team 1'));
    await tester.pumpAndSettle();
    counter.start();
    final watch = Stopwatch()..start();
    await tester.tap(find.text('Team 2'));
    await tester.pump();
    final firstFrame = watch.elapsedMicroseconds / 1000;
    await tester.pumpAndSettle();
    final tiles = counter.stop<ConversationTile>();
    debugPrint(
      'PERF switch chat: $tiles chat rows rebuilt, '
      'first frame ${firstFrame.toStringAsFixed(1)} ms',
    );
    // The row left and the row opened (every row on screen before).
    expect(tiles, lessThanOrEqualTo(2));

    // A new message in another chat moves it to the top.
    counter.start();
    repo.listed = [
      _chat(30, last: 60),
      for (final c in repo.listed)
        if (c.gid != 'g30') c,
    ];
    repo.chats.add(repo.listed);
    await tester.pump();
    watch
      ..reset()
      ..start();
    await tester.pump();
    final frame = watch.elapsedMicroseconds / 1000;
    await tester.pumpAndSettle();
    final moved = counter.stop<ConversationTile>();
    debugPrint(
      'PERF chat list update: $moved chat rows rebuilt, '
      '${frame.toStringAsFixed(1)} ms',
    );
    // Only the chat that changed (every row on screen before).
    expect(moved, 1);

    // Typing in the composer.
    final field = find.descendant(
      of: find.byType(ChatComposerField),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'h');
    await tester.pumpAndSettle();
    counter.start();
    watch
      ..reset()
      ..start();
    const typed = 'hello there';
    for (var n = 2; n <= typed.length; n++) {
      await tester.enterText(field, typed.substring(0, n));
      await tester.pump();
    }
    watch.stop();
    final perKey = counter.stop<Widget>() / 10;
    debugPrint(
      'PERF typing: ${perKey.toStringAsFixed(0)} elements rebuilt per key, '
      '${(watch.elapsedMicroseconds / 10000).toStringAsFixed(1)} ms per key',
    );
    // The text field itself; not the send button's subtree (87 before).
    expect(perKey, lessThan(60));
  });
}

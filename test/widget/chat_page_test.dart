import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_cache_usage.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_connection_status.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/pages/chat_page.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_files_panel.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_info_panel.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_members_panel.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_thread_header.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_wallpaper.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_list.dart';
import 'package:work_nexus/features/chat/presentation/widgets/scroll_to_latest_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// In-memory [ChatRepository] that records the commands it receives.
class _FakeChatRepository implements ChatRepository {
  ChatConnectionStatus status = const ChatConnectionStatus.online(
    selfUserId: 40,
  );
  final calls = <String>[];

  static final _at = DateTime(2026, 10, 8, 9, 30);

  ChatMessage _msg(
    String gid,
    int sender,
    String text, {
    SendState state = SendState.sent,
    int? serverId,
  }) => ChatMessage(
    accountId: 'acc',
    gid: gid,
    serverId: serverId,
    chatGid: 'g1',
    senderId: sender,
    sentAt: _at,
    content: MessageContent.text(text),
    isMine: sender == 40,
    sendState: state,
  );

  @override
  Stream<ChatConnectionStatus> watchStatus(String accountId) =>
      Stream.value(status);

  @override
  Stream<ChatMessage> watchIncoming() => const Stream.empty();

  @override
  Future<Result<void>> setGroupAvatar(
    String a,
    String c, {
    String? text,
    String? color,
    Uint8List? image,
  }) async => const Ok(null);

  @override
  Future<Result<void>> setMyAvatar(String a, Uint8List image) async =>
      const Ok(null);

  @override
  Future<Result<void>> refreshUsers(String a) async => const Ok(null);

  @override
  Future<Result<String>> createGroupChat(
    String a, {
    required String name,
    required List<int> memberIds,
  }) async => const Ok('new');

  @override
  Future<Result<Duration>> videoDuration(String a, MessageContent v) async =>
      const Ok(Duration(minutes: 1, seconds: 23));

  @override
  Stream<List<ChatMessage>> watchAttachments(String a, String c) =>
      const Stream.empty();

  @override
  Future<Result<ChatCacheUsage>> cacheUsage() async => const Ok(
    ChatCacheUsage(
      totalBytes: 734003200,
      limitBytes: 2147483648,
      chats: [
        ChatCacheChatUsage(accountId: 'acc', chatGid: 'g1', bytes: 524288000),
        ChatCacheChatUsage(
          accountId: 'acc',
          chatGid: '31&40',
          bytes: 104857600,
        ),
      ],
    ),
  );

  @override
  Future<Result<void>> clearCache({String? accountId, String? chatGid}) async =>
      const Ok(null);

  @override
  void setCacheLimit(int bytes) {}

  @override
  Stream<double> watchDownloadProgress(String a, MessageContent c) =>
      const Stream.empty();

  @override
  void cancelDownload(String a, MessageContent c) {}

  @override
  Future<Result<Map<String, String>>> roleNames(String a) async =>
      const Ok({'op': 'Operations'});

  @override
  void setVideoAutoDownloadLimit(int bytes) {}

  @override
  Future<bool> isAttachmentCached(String a, MessageContent c) async => true;

  @override
  Stream<int?> watchSelfUserId(String a) => Stream.value(40);

  @override
  Future<Result<String>> openDirectChat(String a, int u) async => Ok('$u&40');

  @override
  Future<Result<void>> setMessagePinned(
    String a,
    String c,
    int id, {
    required bool pinned,
  }) async => const Ok(null);

  @override
  Future<Result<List<int>>> members(String a, String c) async => const Ok([]);

  @override
  Stream<List<ChatConversation>> watchConversations(String accountId) =>
      Stream.value([
        ChatConversation(
          accountId: 'acc',
          gid: 'g1',
          type: ChatType.group,
          name: 'VN Mobile Team',
          unreadCount: 3,
          lastActiveAt: _at,
          lastMessage: _msg('m2', 31, 'hi [@Thanh](@#40)', serverId: 502),
        ),
        ChatConversation(
          accountId: 'acc',
          gid: '31&40',
          type: ChatType.one2one,
          name: '',
          peerUserId: 31,
          lastActiveAt: _at,
        ),
      ]);

  @override
  Stream<List<ChatUser>> watchUsers(String accountId) => Stream.value(const [
    ChatUser(accountId: 'acc', userId: 31, account: 'dyno', realname: 'Dyno'),
  ]);

  @override
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
  }) => Stream.value([
    _msg('m1', 40, 'xin chào'),
    _msg('m2', 31, 'hi [@Thanh](@#40)', serverId: 502),
    _msg('m3', 40, 'lost', state: SendState.failed),
  ]);

  @override
  Future<Result<void>> connect(String accountId) async {
    calls.add('connect');
    return const Ok(null);
  }

  @override
  Future<void> disconnect(String accountId) async {}

  @override
  Future<Result<void>> trustCertificate(String a, String fingerprint) async {
    calls.add('trust $fingerprint');
    return const Ok(null);
  }

  @override
  Future<Result<void>> refreshMessages(String a, String chatGid) async {
    calls.add('refresh $chatGid');
    return const Ok(null);
  }

  @override
  Future<Result<int>> loadOlderMessages(
    String a,
    String chatGid, {
    int? beforeServerId,
    bool inWindow = false,
  }) async => const Ok(0);

  @override
  Stream<List<ChatMessage>> watchMessagesInRange(
    String a,
    String chatGid, {
    required int fromIndex,
    required int toIndex,
  }) => Stream.value([
    _msg('old1', 31, 'the very first message', serverId: 1).copyWith(index: 1),
    _msg('old2', 40, 'the second one', serverId: 2).copyWith(index: 2),
  ]);

  @override
  Future<Result<({int from, int to})?>> loadMessagesAround(
    String a,
    String chatGid,
    int serverId,
  ) async {
    calls.add('around $serverId');
    return const Ok((from: 1, to: 2));
  }

  @override
  Future<Result<int>> loadNewerMessages(
    String a,
    String chatGid, {
    required int afterServerId,
  }) async => const Ok(0);

  @override
  Future<Result<int?>> joinWindowToTimeline(
    String a,
    String chatGid, {
    required int fromIndex,
    required int toIndex,
  }) async => const Ok(null);

  @override
  Future<Result<int>> countOlderMessages(
    String a,
    String chatGid, {
    required DateTime before,
  }) async => const Ok(0);

  @override
  Future<Result<void>> sendText(
    String a,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  }) async {
    calls.add('send $chatGid $text');
    return const Ok(null);
  }

  @override
  Future<Result<void>> retrySend(String a, String messageGid) async {
    calls.add('retry $messageGid');
    return const Ok(null);
  }

  @override
  Future<Result<void>> markRead(String a, String chatGid) async {
    calls.add('read $chatGid');
    return const Ok(null);
  }

  @override
  Future<Result<Uint8List>> loadAttachment(
    String a,
    MessageContent c, {
    bool thumbnail = false,
  }) async => const Err(NotFoundFailure('none'));

  // Members added after these tests were written; not exercised here yet.
  @override
  Stream<ChatMessage?> watchMessage(String a, String c, int id) =>
      Stream.value(null);

  @override
  Stream<List<ChatMessage>> watchReplies(String a, String c) =>
      Stream.value(const []);

  @override
  Future<Result<void>> fetchMessages(String a, String c, List<int> ids) async =>
      const Ok(null);

  @override
  Future<Result<void>> sendFile(
    String a,
    String c, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) async => const Ok(null);

  @override
  Future<Result<void>> setChatStarred(
    String a,
    String c, {
    required bool starred,
  }) async => const Ok(null);

  @override
  Future<Result<void>> setChatMuted(
    String a,
    String c, {
    required bool muted,
  }) async {
    calls.add('mute $c $muted');
    return const Ok(null);
  }

  @override
  Future<Result<void>> sendEmoji(String a, String c, String code) async {
    calls.add('emoji $c $code');
    return const Ok(null);
  }

  @override
  Future<Result<void>> retract(String a, String g) async => const Ok(null);

  @override
  Stream<double> watchUploadProgress(String g) => const Stream.empty();

  @override
  Uint8List? pendingUploadBytes(String g) => null;

  @override
  Future<Result<Uint8List>> pendingVideoThumbnail(String g, String n) async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<String>> attachmentFile(String a, MessageContent c) async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<Uint8List>> videoThumbnail(String a, MessageContent v) async =>
      const Err(NotFoundFailure('none'));

  @override
  Future<Result<int>> memberCount(String a, String c) async => const Ok(3);
}

void main() {
  late _FakeChatRepository repo;

  setUp(() => repo = _FakeChatRepository());

  Future<void> pumpChat(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    String search = '',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSearchProvider.overrideWith((ref) => search),
          chatRepositoryProvider.overrideWithValue(repo),
          chatAccountsProvider.overrideWithValue(const [
            Account(
              id: 'acc',
              workspaceId: 'ws',
              providerType: ProviderType.zentao,
              handle: 'Thanh',
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

  Future<void> openTeamChat(WidgetTester tester) async {
    await tester.tap(find.text('VN Mobile Team'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists chats with titles, previews and unread counts', (
    tester,
  ) async {
    await pumpChat(tester);

    expect(find.text('VN Mobile Team'), findsOneWidget);
    expect(find.text('Dyno'), findsOneWidget, reason: '1:1 titled by peer');
    expect(
      find.text('Dyno: hi @Thanh', findRichText: true),
      findsOneWidget,
      reason: 'mention flattened, group preview names its sender',
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Select a conversation'), findsOneWidget);
  });

  testWidgets('a chat row shows the hand cursor under the mouse', (
    tester,
  ) async {
    await pumpChat(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('VN Mobile Team')));
    await tester.pump();

    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });

  testWidgets('search narrows the list', (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byType(TextField).first, 'dyn');
    await tester.pumpAndSettle();

    expect(find.text('Dyno'), findsOneWidget);
    expect(find.text('VN Mobile Team'), findsNothing);
  });

  testWidgets('the search box keeps its height with or without text', (
    tester,
  ) async {
    await pumpChat(tester);
    final box = find.byType(TextField).first;
    final empty = tester.getSize(box).height;

    await tester.enterText(box, 'dyn');
    await tester.pumpAndSettle();

    expect(empty, greaterThanOrEqualTo(36));
    expect(tester.getSize(box).height, empty);
  });

  testWidgets('a rebuilt chat list shows the search it filters by', (
    tester,
  ) async {
    // Coming back from the board builds the list anew while the search is
    // still set: the box must show the text still filtering it.
    await pumpChat(tester, search: 'dyn');

    expect(find.widgetWithText(TextField, 'dyn'), findsOneWidget);
    expect(find.text('VN Mobile Team'), findsNothing);
  });

  testWidgets('opening a chat refreshes it, marks it read, shows messages', (
    tester,
  ) async {
    await pumpChat(tester);
    await openTeamChat(tester);

    expect(repo.calls, containsAllInOrder(['refresh g1', 'read g1']));
    expect(find.text('xin chào', findRichText: true), findsOneWidget);
    expect(find.text('hi @Thanh', findRichText: true), findsWidgets);
    expect(find.text('Dyno'), findsWidgets, reason: 'sender shown in groups');
  });

  testWidgets('switching chats keeps the background, not the message list', (
    tester,
  ) async {
    await pumpChat(tester);
    await openTeamChat(tester);
    final background = tester.renderObject(find.byType(ChatBackground));
    final list = tester.state(find.byType(MessageList));

    // The chat list comes first in the tree, before the open thread.
    await tester.tap(find.text('Dyno').first);
    await tester.pumpAndSettle();

    expect(
      tester.renderObject(find.byType(ChatBackground)),
      same(background),
      reason: 'not built and painted again on every switch',
    );
    expect(tester.state(find.byType(MessageList)), isNot(same(list)));
  });

  testWidgets('the header bell mutes this chat, not every notification', (
    tester,
  ) async {
    await pumpChat(tester);
    await openTeamChat(tester);

    await tester.tap(find.byTooltip('Mute chat'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('mute g1 true'));
  });

  testWidgets('the header shows the chat info beside or as a dialog', (
    tester,
  ) async {
    await pumpChat(tester);
    await openTeamChat(tester);
    expect(find.byIcon(PhosphorIconsLight.info), findsNothing);
    expect(find.byType(ChatInfoPanel), findsOneWidget, reason: 'room beside');

    await pumpChat(tester, size: const Size(900, 700));
    expect(find.byType(ChatInfoPanel), findsNothing, reason: 'no room');
    await tester.tap(find.byType(ChatThreadHeader));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(ChatInfoPanel),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(PhosphorIconsLight.x));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('without room, a panel slides over the messages', (tester) async {
    await pumpChat(tester, size: const Size(1000, 700));
    await openTeamChat(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    container
        .read(chatSidePanelProvider((accountId: 'acc', chatGid: 'g1')).notifier)
        .state = ChatSidePanel
        .files;
    await tester.pumpAndSettle();

    // The messages keep their width; the panel is drawn over them.
    expect(find.byType(ChatFilesPanel), findsOneWidget);
    expect(tester.getSize(find.byType(MessageList)).width, greaterThan(500));

    await tester.tapAt(const Offset(500, 400));
    await tester.pumpAndSettle();
    expect(find.byType(ChatFilesPanel), findsNothing);
  });

  testWidgets('members open as their own panel from the chat info', (
    tester,
  ) async {
    await pumpChat(tester);
    await openTeamChat(tester);

    expect(find.byType(ChatMembersPanel), findsNothing);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatMembersPanel), findsOneWidget);
    expect(find.byType(ChatInfoPanel), findsNothing);
  });

  testWidgets('a jump asked before the chat opens (a notification tap) '
      'is taken once the chat shows', (tester) async {
    await pumpChat(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    const thread = (accountId: 'acc', chatGid: 'g1');
    container.read(chatJumpRequestProvider(thread).notifier).state = 502;
    final highlighted = <int?>[];
    container.listen(
      chatHighlightedMessageProvider(thread),
      (_, id) => highlighted.add(id),
    );

    await openTeamChat(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(chatJumpRequestProvider(thread)), isNull);
    expect(highlighted, contains(502));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a jump far back shows a window around the message, and the '
      'latest-messages button leaves it', (tester) async {
    await pumpChat(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatPage)),
    );
    const thread = (accountId: 'acc', chatGid: 'g1');
    await openTeamChat(tester);
    expect(find.text('the very first message'), findsNothing);

    container.read(chatJumpRequestProvider(thread).notifier).state = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.calls, contains('around 1'));
    expect(
      container.read(chatMessageWindowProvider(thread)),
      isA<AroundWindow>(),
    );
    expect(find.text('the very first message'), findsOneWidget);
    // The newest messages are not part of the window.
    expect(find.text('xin chào'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byType(ScrollToLatestButton));
    await tester.pumpAndSettle();

    expect(
      container.read(chatMessageWindowProvider(thread)),
      isA<LiveWindow>(),
    );
    expect(find.text('xin chào'), findsOneWidget);
    expect(find.text('the very first message'), findsNothing);
  });

  testWidgets('Enter sends, Shift+Enter does not', (tester) async {
    await pumpChat(tester);
    await openTeamChat(tester);
    final composer = find.byType(TextField).last;

    await tester.enterText(composer, 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('send')), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('send g1 first line'));
  });

  testWidgets('the like button sends a large emoji, not text', (tester) async {
    await pumpChat(tester);
    await openTeamChat(tester);

    await tester.tap(find.byTooltip('Send a like'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('emoji g1 :thumbsup:'));
    expect(repo.calls.where((c) => c.startsWith('send')), isEmpty);
  });

  testWidgets('a failed message can be retried', (tester) async {
    await pumpChat(tester);
    await openTeamChat(tester);

    await tester.tap(find.text('Not sent · Retry'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('retry m3'));
  });

  testWidgets('an untrusted certificate can be reviewed and trusted', (
    tester,
  ) async {
    repo.status = const ChatConnectionStatus.needsTrust(
      host: 'zentao.example',
      fingerprint: 'AE:C6:E8',
      subject: 'CN=cnezsoft',
      issuer: 'CN=cnezsoft',
    );
    await pumpChat(tester);

    await tester.tap(find.text('Review certificate'));
    await tester.pumpAndSettle();
    expect(find.text('AE:C6:E8'), findsOneWidget);

    await tester.tap(find.text('Trust and connect'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('trust AE:C6:E8'));
    expect(find.text('AE:C6:E8'), findsNothing, reason: 'dialog closed');
  });

  testWidgets('being kicked explains why and offers to reconnect', (
    tester,
  ) async {
    repo.status = const ChatConnectionStatus.signedOut(
      message: 'x',
      kicked: true,
    );
    await pumpChat(tester);

    expect(find.textContaining('signed in somewhere else'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('connect'));
  });
}

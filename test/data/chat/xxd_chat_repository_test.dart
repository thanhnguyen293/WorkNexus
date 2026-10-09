import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_connection.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_server_info.dart';
import 'package:work_nexus/features/chat/data/repositories/xxd_chat_repository.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_connection_status.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

import 'support/fake_xxd_server.dart';

class _MemoryCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String ref) async => values[ref];

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;
}

const _acc = 'acc';
const _t0 = 1791345529; // server time, seconds

Map<String, Object?> _msg(
  int id, {
  String cgid = 'g1',
  int user = 31,
  String content = 'hi',
  String type = 'plain',
}) => {
  'gid': 'm$id',
  'cgid': cgid,
  'id': id,
  'index': id,
  'user': user,
  'date': _t0 + id,
  'content': content,
  'contentType': type,
  'type': 'normal',
  'deleted': false,
};

void main() {
  late AppDatabase db;
  late FakeXxdServer server;
  late FakeXxdHttp http;
  late _MemoryCredentialStore store;
  late XxdChatRepository repo;
  late List<XxdCredentials> opened;
  late List<Object> errors;
  final history = <int, Map<String, Object?>>{};
  var nextId = 1000;
  final now = DateTime(2026, 10, 8, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: _acc,
            workspaceId: 'ws',
            providerType: 'zentao',
            handle: 'demo',
            baseUrl: const Value('https://zt.test:4433/zentao'),
            credentialsRef: const Value('secret:acc'),
          ),
        );
    store = _MemoryCredentialStore()..values['secret:acc'] = 'pw';
    server = FakeXxdServer()
      ..chats = [
        {
          'gid': 'g1',
          'type': 'group',
          'name': 'Team',
          'lastActiveTime': _t0 + 100,
          'lastMessage': 100,
          'lastReadMessageIndex': 99,
          'lastMessageInfo': _msg(100, content: 'hello'),
        },
        {
          'gid': '31&40',
          'type': 'one2one',
          'name': '',
          'lastActiveTime': _t0,
          'lastMessage': 0,
          'lastReadMessageIndex': 0,
        },
      ];
    history
      ..clear()
      ..addEntries([for (var i = 1; i <= 120; i++) MapEntry(i, _msg(i))]);
    server.onRequest = (req) {
      final params = req['params'] as List<Object?>? ?? const [];
      final data = switch (req['method']) {
        'usergetlist' => [
          for (final id in params.first! as List)
            {'id': id, 'account': 'u$id', 'realname': 'User $id'},
        ],
        'chatgetbygid' => {
          'gid': params.first,
          'type': 'group',
          'name': 'New chat',
          'lastActiveTime': _t0 + 500,
        },
        'messagesend' => [
          for (final m in params.first! as List)
            {
              ...(m! as Map<String, Object?>),
              'id': ++nextId,
              'date': _t0 + 900,
            },
        ],
        'chatstar' => {'gid': params[1], 'star': params[0]},
        'chatgetmessageinfo' => {'lastMessage': 120, 'messageCount': 120},
        'chatsetlastreadmessagebyindex' => {'gid': params[0], 'id': params[1]},
        // `[cgid, startId, reverse, limit, returnID]`: 50 back from startId,
        // or forward when not reverse.
        'messagesync' when params[2] == false => [
          for (var id = params[1]! as int; id < (params[1]! as int) + 50; id++)
            ?history[id],
        ],
        'messagesync' => [
          for (
            var id = params[1]! as int;
            id > 0 && id > (params[1]! as int) - 50;
            id--
          )
            ?history[id],
        ],
        'messagegetlist' => [for (final id in params[1]! as List) ?history[id]],
        _ => null,
      };
      return data == null
          ? null
          : {
              'method': req['method'],
              'rid': req['rid'],
              'result': 'success',
              'data': data,
            };
    };
    http = FakeXxdHttp(serverInfoOk());
    opened = [];
    errors = [];
    repo = XxdChatRepository(
      local: ChatLocalDatasource(db),
      credentials: store,
      openConnection: (c) {
        opened.add(c);
        return XxdConnection(
          credentials: c,
          http: http,
          connector: server.connect,
          requestTimeout: const Duration(seconds: 1),
          backoff: (_) => const Duration(milliseconds: 10),
        );
      },
      onError: (e, _) => errors.add(e),
      http: http,
      now: () => now,
    );
  });

  tearDown(() async {
    await repo.disconnect(_acc);
    await db.close();
    expect(errors, isEmpty);
  });

  Future<T> eventually<T>(Stream<T> stream, bool Function(T) done) =>
      stream.firstWhere(done).timeout(const Duration(seconds: 3));

  ChatConversation? byGid(List<ChatConversation> list, String gid) =>
      list.where((c) => c.gid == gid).firstOrNull;

  test('connect stores the chat list, peers and own user id', () async {
    expect((await repo.connect(_acc)).isOk, isTrue);

    final chats = await eventually(
      repo.watchConversations(_acc),
      (l) => l.length == 2 && byGid(l, '31&40')?.peerUserId == 31,
    );
    final users = await eventually(
      repo.watchUsers(_acc),
      (u) => u.any((x) => x.userId == 31),
    );

    final group = byGid(chats, 'g1')!;
    expect(group.type, ChatType.group);
    expect(group.unreadCount, 1);
    expect(group.lastMessage?.content, const MessageContent.text('hello'));
    expect(group.lastMessage?.isMine, isFalse);
    expect(chats.first.gid, 'g1', reason: 'most recently active first');
    // The login reply stores the signed-in user too.
    expect(users.firstWhere((u) => u.userId == 31).realname, 'User 31');
    expect(
      await repo.watchStatus(_acc).first,
      const ChatConnectionStatus.online(selfUserId: 40),
    );
    expect(opened.single.server, Uri.parse('https://zt.test:11443'));
    expect(opened.single.account, 'demo');
    expect(opened.single.password, 'pw');
  });

  test('a pushed message is stored and bumps unread', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    server.current.push({
      'method': 'messagesend',
      'result': 'success',
      'data': [_msg(101, content: 'new', type: 'text')],
    });

    final chat = await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.unreadCount == 2,
    );
    expect(
      byGid(chat, 'g1')!.lastMessage?.content,
      const MessageContent.text('new', markdown: true),
    );
    final messages = await repo.watchMessages(_acc, 'g1').first;
    expect(messages.last.gid, 'm101');
  });

  test('a live message from someone else is announced once', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    final incoming = <String>[];
    final sub = repo.watchIncoming().listen((m) => incoming.add(m.gid));

    final push = {
      'method': 'messagesend',
      'result': 'success',
      'data': [_msg(102, user: 77)],
    };
    server.current.push(push);
    await eventually(
      repo.watchMessages(_acc, 'g1'),
      (l) => l.last.gid == 'm102',
    );
    // A re-delivery of the same message is not new.
    server.current.push(push);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(incoming, ['m102']);
  });

  test('pin and unpin pushes replace the pinned list', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    server.current.push({
      'method': 'chatPinMessages',
      'result': 'success',
      'data': {
        'cgid': 'g1',
        'pinned': [101],
        'allPinned': [100, 101],
      },
    });
    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.pinnedMessageIds.length == 2,
    );
    server.current.push({
      'method': 'chatUnpinMessages',
      'result': 'success',
      'data': {
        'cgid': 'g1',
        'unpinned': [100],
        'allPinned': [101],
      },
    });
    final chats = await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.pinnedMessageIds.length == 1,
    );
    expect(byGid(chats, 'g1')!.pinnedMessageIds, [101]);
  });

  test('sign-in/out pushes and avatar changes are stored', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    server.current.push({
      'method': 'userlogin',
      'result': 'success',
      'data': {
        'id': 77,
        'account': 'kyo',
        'realname': 'Kyo',
        'status': 'online',
      },
    });
    await eventually(
      repo.watchUsers(_acc),
      (u) => u.any((x) => x.userId == 77 && x.status == 'online'),
    );
    server.current.push({
      'method': 'userlogout',
      'result': 'success',
      'data': {'id': 77},
    });
    await eventually(
      repo.watchUsers(_acc),
      (u) => u.any((x) => x.userId == 77 && x.status == 'offline'),
    );
    server.current.push({
      'method': 'chatsetavatar',
      'result': 'success',
      'data': {
        'gid': 'g1',
        'avatar': {
          'type': 'text',
          'data': {'bgColor': '#37C3A4', 'customText': 'VN'},
        },
      },
    });
    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.avatarJson?.contains('#37C3A4') ?? false,
    );
  });

  test(
    'notifications land in the xuanbot chat, created when missing',
    () async {
      await repo.connect(_acc);
      await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

      server.current.push({
        'method': 'syncNotifications',
        'result': 'success',
        'data': [
          {
            'id': 5,
            'title': 'Task #12 assigned to you',
            'content': 'Please **review**',
            'contentType': 'text',
            'url': 'https://zentao.example/task-view-12.html',
            'actions': [
              {'label': 'Open', 'url': 'https://zentao.example/my'},
            ],
            'sender': {'id': 'zentao', 'realname': 'ZenTao'},
            'date': _t0 + 950,
          },
        ],
      });

      final chats = await eventually(
        repo.watchConversations(_acc),
        (l) => byGid(l, '40&xuanbot') != null,
      );
      expect(byGid(chats, '40&xuanbot')?.type, ChatType.bot);
      final messages = await eventually(
        repo.watchMessages(_acc, '40&xuanbot'),
        (m) => m.isNotEmpty,
      );
      final content = messages.single.content as NotificationContent;
      expect(content.title, 'Task #12 assigned to you');
      expect(content.text, 'Please **review**');
      expect(content.url, 'https://zentao.example/task-view-12.html');
      expect(content.actions.single.label, 'Open');
      expect(content.sender, 'ZenTao');
      expect(messages.single.senderId, 0);
    },
  );

  test('pinning a chat moves it first; a push from elsewhere too', () async {
    await repo.connect(_acc);
    var chats = await eventually(
      repo.watchConversations(_acc),
      (l) => l.length == 2,
    );
    final last = chats.last.gid;

    final r = await repo.setChatStarred(_acc, last, starred: true);
    expect(r, isA<Ok<void>>());
    chats = await eventually(
      repo.watchConversations(_acc),
      (l) => l.first.gid == last && l.first.starred,
    );
    expect(
      server.requests.lastWhere((r) => r['method'] == 'chatstar')['params'],
      [true, last],
    );

    server.current.push({
      'method': 'chatStar',
      'result': 'success',
      'data': {'gid': last, 'star': false},
    });
    await eventually(
      repo.watchConversations(_acc),
      (l) => !byGid(l, last)!.starred,
    );
  });

  test('role names come from sysgetdepts, asked once', () async {
    server.onRequest = (req) => req['method'] == 'sysgetdepts'
        ? {
            'method': 'sysgetdepts',
            'rid': req['rid'],
            'result': 'success',
            // As xxd 9 replies: departments and roles inside `data`, the
            // reply's own `roles` empty.
            'data': {
              'depts': {
                '1': {'name': 'Mobile'},
              },
              'roles': {'dev': '研发', 'op': 'Operations', 'x': ''},
            },
            'roles': '',
          }
        : null;
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    final names = await repo.roleNames(_acc);
    expect(names, isA<Ok<Map<String, String>>>());
    expect((names as Ok<Map<String, String>>).value, {
      'dev': '研发',
      'op': 'Operations',
    });
    await repo.roleNames(_acc);
    expect(
      server.requests.where((r) => r['method'] == 'sysgetdepts'),
      hasLength(1),
    );
  });

  test('a message in an unknown chat fetches that chat', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    server.current.push({
      'method': 'messagesend',
      'result': 'success',
      'data': [_msg(300, cgid: 'g9', user: 77)],
    });

    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g9') != null,
    );
    await eventually(
      repo.watchUsers(_acc),
      (u) => u.any((x) => x.userId == 77),
    );
    expect(
      server.requests
          .where((r) => r['method'] == 'chatgetbygid')
          .single['params'],
      ['g9'],
    );
  });

  test('sendText shows the message as pending, then sent', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    final seen = <SendState>[];
    final sub = repo.watchMessages(_acc, 'g1').listen((l) {
      final mine = l.where((m) => m.isMine);
      if (mine.isNotEmpty) seen.add(mine.last.sendState);
    });

    final result = await repo.sendText(_acc, 'g1', 'xin chào');
    final sent = await eventually(
      repo.watchMessages(_acc, 'g1'),
      (l) => l.any((m) => m.isMine && m.serverId != null),
    );
    await sub.cancel();

    expect(result.isOk, isTrue);
    final mine = sent.lastWhere((m) => m.isMine);
    expect(mine.sendState, SendState.sent);
    expect(mine.content, const MessageContent.text('xin chào'));
    expect(seen.first, SendState.pending);
    final req = server.requests.lastWhere((r) => r['method'] == 'messagesend');
    expect((req['params']! as List).first, [
      allOf(
        containsPair('cgid', 'g1'),
        containsPair('contentType', 'plain'),
        containsPair('user', 40),
      ),
    ]);
  });

  test('sending offline fails; retry after connecting delivers it', () async {
    final offline = await repo.sendText(_acc, 'g1', 'later');
    expect(offline.failureOrNull, isA<NetworkFailure>());
    final failed = (await repo.watchMessages(_acc, 'g1').first).single;
    expect(failed.sendState, SendState.failed);

    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    final retried = await repo.retrySend(_acc, failed.gid);

    expect(retried.isOk, isTrue);
    final after = await repo.watchMessages(_acc, 'g1').first;
    expect(
      after.singleWhere((m) => m.gid == failed.gid).sendState,
      SendState.sent,
    );
  });

  test(
    'older pages start before the oldest shown message, across gaps',
    () async {
      await repo.connect(_acc);
      await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
      expect((await repo.refreshMessages(_acc, 'g1')).isOk, isTrue);
      // A far older message stored on its own (as a pinned message or reply
      // parent is): history now has a gap between it and the newest page.
      server.current.push({
        'method': 'messagesend',
        'result': 'success',
        'data': [_msg(3)],
      });
      await eventually(
        repo.watchMessages(_acc, 'g1', limit: 500),
        (m) => m.any((x) => x.serverId == 3),
      );

      // Paging from the oldest *stored* message would find almost nothing.
      expect(
        (await repo.loadOlderMessages(
          _acc,
          'g1',
          beforeServerId: 71,
        )).valueOrNull,
        50,
      );
      final stored = await repo.watchMessages(_acc, 'g1', limit: 500).first;
      expect(stored.where((m) => m.serverId! < 71).length, 51);
    },
  );

  test('refresh then loadOlder page backwards through history', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);

    expect((await repo.refreshMessages(_acc, 'g1')).isOk, isTrue);
    expect((await repo.loadOlderMessages(_acc, 'g1')).valueOrNull, 50);
    expect((await repo.loadOlderMessages(_acc, 'g1')).valueOrNull, 20);
    expect((await repo.loadOlderMessages(_acc, 'g1')).valueOrNull, 0);

    final all = await repo.watchMessages(_acc, 'g1', limit: 500).first;
    expect(all.map((m) => m.serverId), [for (var i = 1; i <= 120; i++) i]);
  });

  test('a reply parent fetched by id stays out of the timeline', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    expect((await repo.refreshMessages(_acc, 'g1')).isOk, isTrue);

    expect((await repo.fetchMessages(_acc, 'g1', [3])).isOk, isTrue);
    expect((await repo.watchMessage(_acc, 'g1', 3).first)?.serverId, 3);

    final shown = await repo.watchMessages(_acc, 'g1', limit: 51).first;
    expect(shown.map((m) => m.serverId), [for (var i = 71; i <= 120; i++) i]);
    expect(
      (await repo.countOlderMessages(
        _acc,
        'g1',
        before: shown.first.sentAt,
      )).valueOrNull,
      0,
    );
  });

  test('a jump window around an old message, then newer pages until it '
      'joins the timeline', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    expect((await repo.refreshMessages(_acc, 'g1')).isOk, isTrue);

    final span = (await repo.loadMessagesAround(_acc, 'g1', 3)).valueOrNull;
    expect(span, (from: 1, to: 52));
    final window = await repo
        .watchMessagesInRange(_acc, 'g1', fromIndex: 1, toIndex: 52)
        .first;
    expect(window.map((m) => m.serverId), [for (var i = 1; i <= 52; i++) i]);
    // Not part of the timeline yet.
    final latest = await repo.watchMessages(_acc, 'g1', limit: 500).first;
    expect(latest.first.serverId, 71);

    // 53–70 come with the next page; the window then reaches the timeline.
    expect(
      (await repo.loadNewerMessages(_acc, 'g1', afterServerId: 52)).valueOrNull,
      greaterThan(0),
    );
    expect(
      (await repo.joinWindowToTimeline(
        _acc,
        'g1',
        fromIndex: 1,
        toIndex: 101,
      )).valueOrNull,
      120,
    );
    final joined = await repo.watchMessages(_acc, 'g1', limit: 500).first;
    expect(joined.map((m) => m.serverId), [for (var i = 1; i <= 120; i++) i]);
  });

  test('a refresh that skips ahead cuts off the stale history below', () async {
    await repo.connect(_acc);
    await eventually(repo.watchConversations(_acc), (l) => l.length == 2);
    // Pages 1–50 were stored in an earlier session.
    expect(
      (await repo.loadOlderMessages(_acc, 'g1', beforeServerId: 51)).isOk,
      isTrue,
    );

    expect((await repo.refreshMessages(_acc, 'g1')).isOk, isTrue);

    final shown = await repo.watchMessages(_acc, 'g1', limit: 500).first;
    expect(shown.map((m) => m.serverId), [for (var i = 71; i <= 120; i++) i]);
  });

  test('an untrusted certificate waits for the user, then pins it', () async {
    http.queued.add(
      const Err(
        UntrustedCertificateFailure(
          'untrusted',
          host: 'zt.test',
          fingerprint: 'AA:BB',
          subject: 'CN=cnezsoft',
          issuer: 'CN=cnezsoft',
        ),
      ),
    );

    final first = await repo.connect(_acc);
    expect(first.failureOrNull, isA<UntrustedCertificateFailure>());
    expect(
      await repo.watchStatus(_acc).first,
      const ChatConnectionStatus.needsTrust(
        host: 'zt.test',
        fingerprint: 'AA:BB',
        subject: 'CN=cnezsoft',
        issuer: 'CN=cnezsoft',
      ),
    );

    expect((await repo.trustCertificate(_acc, 'AA:BB')).isOk, isTrue);
    expect(opened.last.pinnedFingerprint, 'AA:BB');
    expect(await repo.watchStatus(_acc).first, isA<ChatOnline>());
  });

  test('without a saved password chat is signed out', () async {
    store.values.clear();

    final result = await repo.connect(_acc);

    expect(result.failureOrNull, isA<AuthFailure>());
    expect(await repo.watchStatus(_acc).first, isA<ChatSignedOut>());
    expect(opened, isEmpty);
  });

  test('being kicked signs out instead of reconnecting', () async {
    await repo.connect(_acc);

    server.current.push({'method': 'userkickoff', 'reason': 'elsewhere'});

    final status = await eventually(
      repo.watchStatus(_acc),
      (s) => s is ChatSignedOut,
    );
    expect((status as ChatSignedOut).kicked, isTrue);
  });

  test(
    'messages left pending by a crash are marked failed on connect',
    () async {
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              accountId: _acc,
              gid: 'stuck',
              cgid: 'g1',
              senderId: 40,
              sentAt: now.subtract(const Duration(minutes: 10)),
              contentType: 'plain',
              content: 'lost',
              sendState: const Value('pending'),
            ),
          );

      await repo.connect(_acc);

      final rows = await repo.watchMessages(_acc, 'g1', limit: 500).first;
      expect(
        rows.singleWhere((m) => m.gid == 'stuck').sendState,
        SendState.failed,
      );
    },
  );

  test('markRead clears unread locally and tells the server', () async {
    await repo.connect(_acc);
    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.unreadCount == 1,
    );

    expect((await repo.markRead(_acc, 'g1')).isOk, isTrue);

    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.unreadCount == 0,
    );
    expect(
      server.requests.lastWhere(
        (r) => r['method'] == 'chatsetlastreadmessagebyindex',
      )['params'],
      ['g1', 100],
    );
  });

  test('a read marker pushed from another device clears unread', () async {
    await repo.connect(_acc);
    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.unreadCount == 1,
    );

    server.current.push({
      'method': 'chatsetlastreadmessagebyindex',
      'result': 'success',
      'data': {'gid': 'g1', 'id': 100},
    });

    await eventually(
      repo.watchConversations(_acc),
      (l) => byGid(l, 'g1')?.unreadCount == 0,
    );
  });

  test(
    'loadAttachment downloads once through a signed URL, then caches',
    () async {
      await repo.connect(_acc);
      await eventually(repo.watchStatus(_acc), (s) => s is ChatOnline);
      // syssessionid arrives right after login.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      const image = MessageContent.image(
        fileId: 27338,
        name: 'image.png',
        size: 3,
        time: 1790842835000,
      );

      final first = await repo.loadAttachment(_acc, image);
      final second = await repo.loadAttachment(_acc, image);

      expect(first.valueOrNull, [1, 2, 3]);
      expect(second.valueOrNull, [1, 2, 3]);
      final uri = http.downloads.single;
      expect(uri.path, '/fileDownload');
      expect(uri.queryParameters, containsPair('id', '27338'));
      expect(uri.queryParameters, containsPair('gid', '40'));
      expect(uri.queryParameters, containsPair('time', '1790842835'));
      expect(uri.queryParameters['sid'], hasLength(32));
    },
  );

  test('text messages have no attachment', () async {
    final result = await repo.loadAttachment(
      _acc,
      const MessageContent.text('hi'),
    );
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}

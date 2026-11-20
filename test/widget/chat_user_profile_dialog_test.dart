import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/person_directory_provider.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/person_profile.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/repositories/person_directory.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/badges.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_connection_status.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_user_profile_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _Repo extends Mock implements ChatRepository {}

class _Directory extends Mock implements PersonDirectory {}

const _account = Account(
  id: 'acc',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'me',
);

const _bug = Ticket(
  id: 'acc:bug:12',
  accountId: 'acc',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: '12',
  externalType: 'bug',
  title: 'Crash on login',
  body: '',
  priority: Priority.high,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: '',
  assignee: 'tran',
  providerEntity: TicketProviderEntity.zentaoBug(),
);

void main() {
  late _Repo repo;
  late _Directory directory;

  setUpAll(() => registerFallbackValue(_account));

  setUp(() {
    repo = _Repo();
    directory = _Directory();
    when(() => repo.watchUsers('acc')).thenAnswer(
      (_) => Stream.value(const [
        ChatUser(accountId: 'acc', userId: 1, account: 'me', realname: 'Me'),
        ChatUser(
          accountId: 'acc',
          userId: 98,
          account: 'tran',
          realname: 'Victor Tran',
          email: 'tran@example.com',
          status: 'online',
        ),
      ]),
    );
    when(() => repo.watchSelfUserId('acc')).thenAnswer((_) => Stream.value(1));
    when(() => repo.watchStatus('acc')).thenAnswer(
      (_) => Stream.value(const ChatConnectionStatus.online(selfUserId: 1)),
    );
    when(() => repo.roleNames('acc')).thenAnswer((_) async => const Ok({}));
    when(() => repo.watchConversations('acc')).thenAnswer(
      (_) => Stream.value(const [
        ChatConversation(
          accountId: 'acc',
          gid: 'g1',
          type: ChatType.group,
          name: 'Mobile team',
        ),
        ChatConversation(
          accountId: 'acc',
          gid: 'g2',
          type: ChatType.group,
          name: 'Backend',
        ),
      ]),
    );
    when(
      () => repo.members('acc', 'g1'),
    ).thenAnswer((_) async => const Ok([1, 98]));
    when(
      () => repo.members('acc', 'g2'),
    ).thenAnswer((_) async => const Ok([1]));
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    int userId = 98,
    List<Ticket>? tickets,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          personDirectoryProvider.overrideWithValue(directory),
          accountsProvider.overrideWith((ref) => Stream.value([_account])),
          ticketsProvider.overrideWith(
            (ref) => Stream.value(tickets ?? [_bug]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ChatUserProfileDialog.show(
                  context,
                  accountId: 'acc',
                  userId: userId,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.text('open')));
  }

  testWidgets('shows contacts, work, shared groups and open tickets', (
    tester,
  ) async {
    when(() => directory.lookup(any(), 98)).thenAnswer(
      (_) async => Ok(
        PersonProfile(
          department: 'VN > Flutter VN',
          wechat: 'tran_wx',
          joined: DateTime(2021, 3, 15),
        ),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Victor Tran'), findsOneWidget);
    expect(find.text('@tran'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('tran@example.com'), findsOneWidget);
    expect(find.text('tran_wx'), findsOneWidget);
    expect(find.text('VN > Flutter VN'), findsOneWidget);
    // Empty fields are left out.
    expect(find.text('Phone'), findsNothing);
    expect(find.text('Mobile team'), findsOneWidget);
    expect(find.text('Backend'), findsNothing);
    expect(find.textContaining('Crash on login'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('shows a placeholder while the tracker profile loads', (
    tester,
  ) async {
    final pending = Completer<Result<PersonProfile>>();
    when(() => directory.lookup(any(), 98)).thenAnswer((_) => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    pending.complete(const Ok(PersonProfile(department: 'QA team')));
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonBox), findsNothing);
    expect(find.text('QA team'), findsOneWidget);
  });

  testWidgets('"+N more" reveals every open ticket, "Show less" folds back', (
    tester,
  ) async {
    when(
      () => directory.lookup(any(), 98),
    ).thenAnswer((_) async => const Ok(PersonProfile()));
    final many = [
      for (var i = 1; i <= 6; i++)
        _bug.copyWith(id: 'acc:bug:$i', externalKey: '$i', title: 'Bug $i'),
    ];
    await pump(tester, tickets: many);
    await tester.pumpAndSettle();

    expect(find.textContaining('Bug '), findsNWidgets(4));
    await tester.tap(find.text('+2 more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bug '), findsNWidgets(6));

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bug '), findsNWidgets(4));
  });

  testWidgets('a ticket opens in the detail panel and closes the popup', (
    tester,
  ) async {
    when(
      () => directory.lookup(any(), 98),
    ).thenAnswer((_) async => const Ok(PersonProfile()));
    final container = await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Crash on login'));
    await tester.pumpAndSettle();

    expect(container.read(appNavProvider).openTicketId, _bug.id);
    expect(find.text('Victor Tran'), findsNothing);
  });

  testWidgets('your own profile offers a new picture, not groups', (
    tester,
  ) async {
    when(
      () => directory.lookup(any(), 1),
    ).thenAnswer((_) async => const Ok(PersonProfile()));
    await pump(tester, userId: 1);
    await tester.pumpAndSettle();

    expect(find.text('Change your picture'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Groups in common'.toUpperCase()), findsNothing);
    verifyNever(() => repo.members(any(), any()));
  });
}

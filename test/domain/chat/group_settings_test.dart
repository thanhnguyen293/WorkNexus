import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_group_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/set_group_admin.dart';
import 'package:work_nexus/features/chat/domain/usecases/transfer_group_ownership.dart';
import 'package:work_nexus/features/chat/domain/usecases/update_group_settings.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_committers.dart';

class _Repo extends Mock implements ChatGroupRepository {}

void main() {
  late _Repo repo;
  const team = ChatConversation(
    accountId: 'a',
    gid: 'g',
    type: ChatType.group,
    name: 'Team',
    adminIds: [7],
    ownerAccount: 'owner',
  );

  setUp(() {
    repo = _Repo();
    when(
      () => repo.setGroupSettings(
        any(),
        any(),
        isPublic: any(named: 'isPublic'),
        adminInvite: any(named: 'adminInvite'),
        committers: any(named: 'committers'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () =>
          repo.setGroupAdmins(any(), any(), any(), admin: any(named: 'admin')),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.transferGroupOwnership(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  group('ChatCommitters', () {
    test('reads and writes what xxd stores', () {
      expect(ChatCommitters.parse('').scope, ChatSendScope.everyone);
      expect(ChatCommitters.parse(r'$ALL').scope, ChatSendScope.everyone);
      expect(ChatCommitters.parse(r'$ADMINS').scope, ChatSendScope.admins);
      final chosen = ChatCommitters.parse('5, 3');
      expect(chosen.scope, ChatSendScope.selected);
      expect(chosen.userIds, {3, 5});
      expect(chosen.encode(), '3,5');
      expect(const ChatCommitters(ChatSendScope.admins).encode(), r'$ADMINS');
      expect(const ChatCommitters(ChatSendScope.everyone).encode(), '');
    });
  });

  group('UpdateGroupSettings', () {
    test('owner and admins edit a live group', () {
      final update = UpdateGroupSettings(repo);
      expect(update.canEdit(team, selfUserId: 1, selfAccount: 'owner'), true);
      expect(update.canEdit(team, selfUserId: 7, selfAccount: 'x'), true);
      expect(update.canEdit(team, selfUserId: 2, selfAccount: 'x'), false);
    });

    test('a public group drops admin-only invites', () async {
      final result = await UpdateGroupSettings(repo)(
        team,
        isPublic: true,
        adminInvite: true,
        committers: const ChatCommitters(ChatSendScope.admins),
      );
      expect(result, isA<Ok<void>>());
      verify(
        () => repo.setGroupSettings(
          'a',
          'g',
          isPublic: true,
          adminInvite: false,
          committers: r'$ADMINS',
        ),
      ).called(1);
    });

    test('chosen members need someone chosen', () async {
      final update = UpdateGroupSettings(repo);
      expect(
        await update(
          team,
          isPublic: false,
          adminInvite: true,
          committers: const ChatCommitters(ChatSendScope.selected),
        ),
        isA<Err<void>>(),
      );
      await update(
        team,
        isPublic: false,
        adminInvite: true,
        committers: const ChatCommitters(ChatSendScope.selected, {4, 2}),
      );
      verify(
        () => repo.setGroupSettings(
          'a',
          'g',
          isPublic: false,
          adminInvite: true,
          committers: '2,4',
        ),
      ).called(1);
    });
  });

  group('SetGroupAdmin and TransferGroupOwnership', () {
    test('only the owner, and never for themself', () async {
      final admin = SetGroupAdmin(repo);
      final transfer = TransferGroupOwnership(repo);
      expect(admin.canSetAdmins(team, selfAccount: 'owner'), true);
      expect(admin.canSetAdmins(team, selfAccount: 'admin'), false);
      expect(transfer.canTransfer(team, selfAccount: 'admin'), false);

      expect(
        await admin(team, 5, admin: true, selfUserId: 7, selfAccount: 'admin'),
        isA<Err<void>>(),
      );
      expect(
        await transfer(team, 1, selfUserId: 1, selfAccount: 'owner'),
        isA<Err<void>>(),
      );

      await admin(team, 5, admin: false, selfUserId: 1, selfAccount: 'owner');
      verify(() => repo.setGroupAdmins('a', 'g', [5], admin: false)).called(1);
      await transfer(team, 5, selfUserId: 1, selfAccount: 'owner');
      verify(() => repo.transferGroupOwnership('a', 'g', 5)).called(1);
    });
  });
}

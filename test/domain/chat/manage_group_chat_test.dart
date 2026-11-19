import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_group_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/add_group_members.dart';
import 'package:work_nexus/features/chat/domain/usecases/dismiss_group_chat.dart';
import 'package:work_nexus/features/chat/domain/usecases/leave_group_chat.dart';
import 'package:work_nexus/features/chat/domain/usecases/remove_group_member.dart';
import 'package:work_nexus/features/chat/domain/usecases/rename_group_chat.dart';

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
      () => repo.renameGroupChat(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.dismissGroupChat(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.leaveGroupChat(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.addGroupMembers(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.removeGroupMembers(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  group('RenameGroupChat', () {
    test('owner and admins may rename a live group', () {
      final rename = RenameGroupChat(repo);
      expect(rename.canRename(team, selfUserId: 1, selfAccount: 'owner'), true);
      expect(rename.canRename(team, selfUserId: 7, selfAccount: 'x'), true);
      expect(rename.canRename(team, selfUserId: 2, selfAccount: 'x'), false);
      expect(
        rename.canRename(
          team.copyWith(archived: true),
          selfUserId: 7,
          selfAccount: 'owner',
        ),
        false,
      );
      expect(
        rename.canRename(
          team.copyWith(type: ChatType.one2one),
          selfUserId: 7,
          selfAccount: 'owner',
        ),
        false,
      );
    });

    test('sends the trimmed name', () async {
      final result = await RenameGroupChat(repo)(team, '  New name ');
      expect(result, isA<Ok<void>>());
      verify(() => repo.renameGroupChat('a', 'g', 'New name')).called(1);
    });

    test('refuses a blank name and skips an unchanged one', () async {
      final rename = RenameGroupChat(repo);
      expect(await rename(team, '   '), isA<Err<void>>());
      expect(await rename(team, ' Team '), isA<Ok<void>>());
      verifyNever(() => repo.renameGroupChat(any(), any(), any()));
    });
  });

  group('DismissGroupChat', () {
    test('only the owner may dismiss a live group', () {
      final dismiss = DismissGroupChat(repo);
      expect(dismiss.canDismiss(team, selfAccount: 'owner'), true);
      expect(dismiss.canDismiss(team, selfAccount: 'admin'), false);
      expect(dismiss.canDismiss(team, selfAccount: null), false);
      expect(
        dismiss.canDismiss(team.copyWith(archived: true), selfAccount: 'owner'),
        false,
      );
    });

    test('dismisses for the owner, refuses anyone else', () async {
      final dismiss = DismissGroupChat(repo);
      expect(await dismiss(team, selfAccount: 'admin'), isA<Err<void>>());
      verifyNever(() => repo.dismissGroupChat(any(), any()));
      expect(await dismiss(team, selfAccount: 'owner'), isA<Ok<void>>());
      verify(() => repo.dismissGroupChat('a', 'g')).called(1);
    });
  });

  group('AddGroupMembers', () {
    test('who may add to a live group', () {
      final add = AddGroupMembers(repo);
      expect(add.canAdd(team, selfUserId: 1, selfAccount: 'owner'), true);
      expect(add.canAdd(team, selfUserId: 7, selfAccount: 'x'), true);
      // Anyone who may post, unless inviting is kept to admins…
      expect(add.canAdd(team, selfUserId: 2, selfAccount: 'x'), true);
      final adminsOnly = team.copyWith(adminInvite: true);
      expect(add.canAdd(adminsOnly, selfUserId: 2, selfAccount: 'x'), false);
      expect(add.canAdd(adminsOnly, selfUserId: 7, selfAccount: 'x'), true);
      // …which a public group overrides.
      expect(
        add.canAdd(
          adminsOnly.copyWith(isPublic: true),
          selfUserId: 2,
          selfAccount: 'x',
        ),
        true,
      );
      // Someone who may not post may not invite either.
      expect(
        add.canAdd(
          team.copyWith(committers: r'$ADMINS'),
          selfUserId: 2,
          selfAccount: 'x',
        ),
        false,
      );
      expect(
        add.canAdd(
          team.copyWith(archived: true),
          selfUserId: 7,
          selfAccount: 'owner',
        ),
        false,
      );
    });

    test('sends each person once, nothing for no one', () async {
      final add = AddGroupMembers(repo);
      expect(await add(team, []), isA<Err<void>>());
      verifyNever(() => repo.addGroupMembers(any(), any(), any()));
      expect(await add(team, [3, 4, 3]), isA<Ok<void>>());
      verify(() => repo.addGroupMembers('a', 'g', [3, 4])).called(1);
    });
  });

  group('RemoveGroupMember', () {
    test('only the owner removes, and never themself', () async {
      final remove = RemoveGroupMember(repo);
      expect(remove.canRemove(team, selfAccount: 'owner'), true);
      expect(remove.canRemove(team, selfAccount: 'admin'), false);
      expect(
        await remove(team, 5, selfUserId: 7, selfAccount: 'admin'),
        isA<Err<void>>(),
      );
      expect(
        await remove(team, 1, selfUserId: 1, selfAccount: 'owner'),
        isA<Err<void>>(),
      );
      verifyNever(() => repo.removeGroupMembers(any(), any(), any()));
      expect(
        await remove(team, 5, selfUserId: 1, selfAccount: 'owner'),
        isA<Ok<void>>(),
      );
      verify(() => repo.removeGroupMembers('a', 'g', [5])).called(1);
    });
  });

  group('LeaveGroupChat', () {
    test('members leave a live group; the owner cannot', () async {
      final leave = LeaveGroupChat(repo);
      expect(leave.canLeave(team, selfAccount: 'member'), true);
      expect(leave.canLeave(team, selfAccount: 'owner'), false);
      expect(leave.canLeave(team, selfAccount: null), false);
      expect(
        leave.canLeave(team.copyWith(archived: true), selfAccount: 'member'),
        false,
      );
      expect(await leave(team, selfAccount: 'owner'), isA<Err<void>>());
      verifyNever(() => repo.leaveGroupChat(any(), any()));
      expect(await leave(team, selfAccount: 'member'), isA<Ok<void>>());
      verify(() => repo.leaveGroupChat('a', 'g')).called(1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/create_group_chat.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  test('needs a name and two other people', () async {
    final create = CreateGroupChat(repo);
    expect(
      await create(accountId: 'a', name: '  ', memberIds: [1, 2]),
      isA<Err<String>>(),
    );
    expect(
      await create(accountId: 'a', name: 'Team', memberIds: [1, 1]),
      isA<Err<String>>(),
    );
    verifyNever(
      () => repo.createGroupChat(
        any(),
        name: any(named: 'name'),
        memberIds: any(named: 'memberIds'),
      ),
    );
  });

  test('creates with a trimmed name and unique members', () async {
    when(() => repo.createGroupChat('a', name: 'Team', memberIds: [1, 2]))
        .thenAnswer((_) async => const Ok('gid'));
    final result = await CreateGroupChat(repo)(
      accountId: 'a',
      name: ' Team ',
      memberIds: [1, 2, 2],
    );
    expect(result.valueOrNull, 'gid');
  });
}

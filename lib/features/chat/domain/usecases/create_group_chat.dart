import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Creates a group chat: needs a name and at least two other people (one
/// person is a one-to-one chat, see OpenDirectChat). Returns its gid.
class CreateGroupChat {
  const CreateGroupChat(this._repository);

  final ChatRepository _repository;

  Future<Result<String>> call({
    required String accountId,
    required String name,
    required List<int> memberIds,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(UnexpectedFailure('A group needs a name'));
    }
    if (memberIds.toSet().length < 2) {
      return const Err(UnexpectedFailure('A group needs at least two people'));
    }
    return _repository.createGroupChat(
      accountId,
      name: trimmed,
      memberIds: memberIds.toSet().toList(),
    );
  }
}

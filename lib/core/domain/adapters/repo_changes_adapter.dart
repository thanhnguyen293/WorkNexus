import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/repo_change.dart';

abstract interface class RepoChangesAdapter {
  Future<Result<List<RepoFileChange>>> listFileChanges(Ticket ticket);
}

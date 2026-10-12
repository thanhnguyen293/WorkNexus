import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/saved_ticket_draft.dart';
import '../../domain/repositories/ticket_draft_repository.dart';
import '../datasources/ticket_draft_local_datasource.dart';
import '../mappers/ticket_draft_mapper.dart';

/// [TicketDraftRepository] over the local database.
class LocalTicketDraftRepository implements TicketDraftRepository {
  const LocalTicketDraftRepository(this._local);

  final TicketDraftLocalDatasource _local;

  @override
  Stream<List<SavedTicketDraft>> watchAll() => _local.watchAll().map(
    (rows) => [for (final row in rows) ?TicketDraftMapper.fromRow(row)],
  );

  @override
  Future<Result<SavedTicketDraft?>> read(String id) => _guard(() async {
    final row = await _local.read(id);
    return row == null ? null : TicketDraftMapper.fromRow(row);
  });

  @override
  Future<Result<void>> save(SavedTicketDraft draft) =>
      _guard(() => _local.save(TicketDraftMapper.toRow(draft)));

  @override
  Future<Result<void>> delete(String id) => _guard(() => _local.delete(id));

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on Exception catch (e) {
      return Err(StorageFailure('Could not keep the draft', cause: e));
    }
  }
}

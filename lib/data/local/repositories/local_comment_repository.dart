import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/repositories/comment_repository.dart';
import '../mappers.dart';

/// Drift-backed [CommentRepository] for a ticket's comment thread.
class LocalCommentRepository implements CommentRepository {
  LocalCommentRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Comment>> watchComments(String ticketId) => _db
      .watchComments(ticketId)
      .map((rows) => rows.map(commentFromRow).toList());

  @override
  Future<void> addComment(Comment comment) async {
    await _db
        .into(_db.comments)
        .insertOnConflictUpdate(commentToCompanion(comment));
  }

  @override
  Future<void> upsertComments(List<Comment> comments) async {
    if (comments.isEmpty) return;
    await _db.batch((b) {
      for (final c in comments) {
        b.insert(
          _db.comments,
          commentToCompanion(c),
          onConflict: DoUpdate((_) => commentToCompanion(c)),
        );
      }
    });
  }
}

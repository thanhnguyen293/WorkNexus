import '../entities/comment.dart';

/// A ticket's provider comments. Posting goes to the provider (through the
/// [ProviderAdapter]); this stores the synced copy the UI reads.
abstract class CommentRepository {
  Stream<List<Comment>> watchComments(String ticketId);
  Future<void> upsertComments(List<Comment> comments);
}

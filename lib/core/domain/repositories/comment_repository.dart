import '../entities/comment.dart';

/// Comments + internal notes for a ticket. Posting to the provider is done by a
/// use case via the [ProviderAdapter]; this stores the local view/cache.
abstract class CommentRepository {
  Stream<List<Comment>> watchComments(String ticketId);
  Future<void> addComment(Comment comment);
  Future<void> upsertComments(List<Comment> comments);
}

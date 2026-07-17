import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';

/// Where a comment lives: a real provider comment, or a private local note.
enum CommentOrigin { provider, internalNote }

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String ticketId,
    required String authorName,
    required String body,
    required DateTime createdAt,
    @Default(CommentOrigin.provider) CommentOrigin origin,
    @Default(true) bool synced,
  }) = _Comment;
}

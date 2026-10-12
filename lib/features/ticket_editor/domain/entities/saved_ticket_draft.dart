import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';

part 'saved_ticket_draft.freezed.dart';

/// A new bug or task not yet saved to ZenTao, kept so it can be picked up
/// again. Files added to it are not kept (only their bytes would be), so a
/// reopened draft starts without them.
@freezed
sealed class SavedTicketDraft with _$SavedTicketDraft {
  const SavedTicketDraft._();

  const factory SavedTicketDraft.bug({
    required String id,
    required String accountId,

    /// The form session the images pasted into the steps were uploaded under;
    /// saving with it ties them to the bug.
    required String uid,
    required DateTime updatedAt,
    required BugDraft draft,
  }) = SavedBugDraft;

  const factory SavedTicketDraft.task({
    required String id,
    required String accountId,
    required String uid,
    required DateTime updatedAt,
    required TaskDraft draft,
  }) = SavedTaskDraft;

  /// What the draft is called so far; empty until a title is written.
  String get title => switch (this) {
    SavedBugDraft(:final draft) => draft.title,
    SavedTaskDraft(:final draft) => draft.name,
  };
}

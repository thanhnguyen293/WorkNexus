import '../../../../core/domain/entities/zentao_ticket_form.dart';

/// A form field that must be filled in (or put right) before saving.
enum DraftField {
  title,
  openedBuilds,
  name,
  type,
  execution,
  product,
  deadline,
}

/// The fields a bug needs before ZenTao takes it (its default required
/// fields: title and the affected build).
class ValidateBugDraft {
  const ValidateBugDraft();

  Set<DraftField> call(BugDraft draft) => {
    if (draft.title.trim().isEmpty) DraftField.title,
    if (draft.openedBuilds.isEmpty) DraftField.openedBuilds,
    if (draft.product == '0' || draft.product.isEmpty) DraftField.product,
  };
}

/// The fields a task needs before ZenTao takes it (name, type, execution),
/// and a deadline ZenTao would refuse for coming before the planned start.
class ValidateTaskDraft {
  const ValidateTaskDraft();

  Set<DraftField> call(TaskDraft draft) => {
    if (draft.name.trim().isEmpty) DraftField.name,
    if (draft.type.isEmpty) DraftField.type,
    if (draft.execution == '0' || draft.execution.isEmpty) DraftField.execution,
    // Both are `yyyy-MM-dd`, so they compare as text.
    if (draft.estStarted.isNotEmpty &&
        draft.deadline.isNotEmpty &&
        draft.deadline.compareTo(draft.estStarted) < 0)
      DraftField.deadline,
  };
}

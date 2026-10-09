import '../../../../core/domain/entities/zentao_ticket_form.dart';

/// A form field that must be filled in before saving.
enum DraftField { title, openedBuilds, name, type, execution, product }

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

/// The fields a task needs before ZenTao takes it (name, type, execution).
class ValidateTaskDraft {
  const ValidateTaskDraft();

  Set<DraftField> call(TaskDraft draft) => {
    if (draft.name.trim().isEmpty) DraftField.name,
    if (draft.type.isEmpty) DraftField.type,
    if (draft.execution == '0' || draft.execution.isEmpty) DraftField.execution,
  };
}

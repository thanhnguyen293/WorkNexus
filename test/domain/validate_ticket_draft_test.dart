import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/features/ticket_editor/domain/usecases/validate_ticket_draft.dart';

void main() {
  test('a bug needs a title, a build and a product', () {
    expect(
      const ValidateBugDraft()(const BugDraft(product: '0', openedBuilds: [])),
      {DraftField.title, DraftField.openedBuilds, DraftField.product},
    );
    expect(
      const ValidateBugDraft()(const BugDraft(product: '4', title: 'Crash')),
      isEmpty,
    );
  });

  test('a task needs a name, a type and an execution', () {
    expect(
      const ValidateTaskDraft()(const TaskDraft(execution: '0', type: '')),
      {DraftField.name, DraftField.type, DraftField.execution},
    );
    expect(
      const ValidateTaskDraft()(const TaskDraft(execution: '9', name: 'x')),
      isEmpty,
    );
  });
}

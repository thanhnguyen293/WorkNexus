import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/features/connections/presentation/widgets/workspace_picker.dart';

Workspace _ws(String id) =>
    Workspace(id: id, name: id, shortCode: 'W', colorValue: 0);

void main() {
  test('no workspace → nothing preselected (a default one is created)', () {
    expect(initialWorkspaceId(const []), isNull);
  });

  test('exactly one workspace → auto-selected', () {
    expect(initialWorkspaceId([_ws('a')]), 'a');
  });

  test('several workspaces → user must choose', () {
    expect(initialWorkspaceId([_ws('a'), _ws('b')]), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/usecases/rename_workspace.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';

const _acme = Workspace(
  id: 'w1',
  name: 'Acme',
  shortCode: 'AC',
  colorValue: 0xFF16A99C,
);

Workspace _ok(Result<Workspace> r) => (r as Ok<Workspace>).value;

void main() {
  const rename = RenameWorkspace();

  test('trims the name and keeps what else the workspace has', () {
    final w = _ok(
      rename(
        const WorkspaceRename(
          workspace: _acme,
          name: '  Globex Corp ',
          shortCode: 'gx',
        ),
      ),
    );
    expect(w.name, 'Globex Corp');
    expect(w.shortCode, 'GX');
    expect(w.id, 'w1');
    expect(w.colorValue, _acme.colorValue);
  });

  test('blank letters are drawn from the name', () {
    String code(String name) => _ok(
      rename(WorkspaceRename(workspace: _acme, name: name, shortCode: ' ')),
    ).shortCode;
    expect(code('Company A'), 'CA');
    expect(code('Big Red Fox Team'), 'BRF');
    expect(code('Globex'), 'GLO');
    expect(code('Go'), 'GO');
  });

  test('a missing or too long name, or long letters, are refused', () {
    Result<Workspace> run(String name, [String code = 'AC']) =>
        rename(WorkspaceRename(workspace: _acme, name: name, shortCode: code));
    expect(run('   '), isA<Err<Workspace>>());
    expect(
      run('x' * (RenameWorkspace.maxNameLength + 1)),
      isA<Err<Workspace>>(),
    );
    expect((run('  ') as Err<Workspace>).failure, isA<ValidationFailure>());
    expect(run('Acme', 'TOOLONG'), isA<Err<Workspace>>());
  });

  test('the personal workspace keeps its name but can change its letters', () {
    const personal = Workspace(
      id: 'p',
      name: 'Personal',
      shortCode: 'P',
      colorValue: 0xFF000000,
      isPersonal: true,
    );
    final w = _ok(
      rename(
        const WorkspaceRename(
          workspace: personal,
          name: 'Something else',
          shortCode: 'me',
        ),
      ),
    );
    expect(w.name, 'Personal');
    expect(w.shortCode, 'ME');
  });
}

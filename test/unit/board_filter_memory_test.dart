import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/shared/board/presentation/providers/filter_providers.dart';

void main() {
  late ProviderContainer container;

  AppNavController nav() => container.read(appNavProvider.notifier);
  FilterController filter() => container.read(filterStateProvider.notifier);
  Set<String> assignees() => container.read(filterStateProvider).assignees;

  setUp(() {
    container = ProviderContainer();
    // Keep the filter alive so it follows every board change.
    container.listen(filterStateProvider, (_, _) {});
    nav()
      ..selectAccount('zt-a')
      ..selectSection(const SectionId('zentao.bugs'))
      ..selectScope('p1');
  });

  tearDown(() => container.dispose());

  test('each product keeps its own filter', () {
    filter().toggleAssignee('an');

    nav().selectScope('p2');
    expect(assignees(), isEmpty);

    nav().selectScope('p1');
    expect(assignees(), {'an'});
  });

  test('another account\'s board does not inherit the filter', () {
    filter().toggleAssignee('an');

    nav()
      ..selectAccount('zt-b')
      ..selectSection(const SectionId('zentao.bugs'))
      ..selectScope('p1');

    expect(assignees(), isEmpty);
  });

  test('a board reopened in another workspace keeps the current one', () {
    filter().setWorkspace('w1');
    nav().selectScope('p2');
    filter().setWorkspace('w2');

    nav().selectScope('p1');

    expect(container.read(filterStateProvider).workspaceId, 'w2');
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/board/domain/value_objects/gitlab_item_kind.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';

void main() {
  test('GitLab boards default to merge requests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(gitlabKindProvider), GitLabItemKind.mergeRequest);
  });
}

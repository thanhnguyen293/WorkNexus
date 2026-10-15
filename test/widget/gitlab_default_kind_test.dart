import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/gitlab/domain/value_objects/gitlab_item_kind.dart';
import 'package:work_nexus/tools/gitlab/presentation/providers/gitlab_board_providers.dart';

void main() {
  test('GitLab boards default to merge requests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(gitlabKindProvider), GitLabItemKind.mergeRequest);
  });
}

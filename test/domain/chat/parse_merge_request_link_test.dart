import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_merge_request_link.dart';

void main() {
  const parse = ParseMergeRequestLink();

  test('self-hosted GitLab merge requests, nested groups and tabs', () {
    expect(parse('https://xddlabs.com/root/tbchat/-/merge_requests/3458'), (
      provider: ProviderType.gitlab,
      host: 'xddlabs.com',
      project: 'root/tbchat',
      number: '3458',
    ));
    expect(
      parse(
        'https://gitlab.com/a/b/c/-/merge_requests/7/diffs?view=inline',
      )?.project,
      'a/b/c',
    );
  });

  test('GitHub pull requests', () {
    expect(parse('https://github.com/flutter/flutter/pull/123/files'), (
      provider: ProviderType.github,
      host: 'github.com',
      project: 'flutter/flutter',
      number: '123',
    ));
  });

  test('other links are not merge requests', () {
    expect(parse('https://github.com/flutter/flutter/issues/1'), isNull);
    expect(parse('https://xddlabs.com/root/tbchat/-/issues/9'), isNull);
    expect(parse('https://zentao.example/task-view-1.html'), isNull);
    expect(parse('not a link'), isNull);
  });
}

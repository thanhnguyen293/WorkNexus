import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/linked_item_kind.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_merge_request_link.dart';

void main() {
  const parse = ParseMergeRequestLink();

  test('self-hosted GitLab merge requests, nested groups and tabs', () {
    expect(parse('https://xddlabs.com/root/tbchat/-/merge_requests/3458'), (
      provider: ProviderType.gitlab,
      kind: LinkedItemKind.mergeRequest,
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
      kind: LinkedItemKind.mergeRequest,
      host: 'github.com',
      project: 'flutter/flutter',
      number: '123',
    ));
  });

  test('GitLab issues, with a trailing slash or a note anchor', () {
    const issue = (
      provider: ProviderType.gitlab,
      kind: LinkedItemKind.issue,
      host: 'xddlabs.com',
      project: 'root/tbchat_packages',
      number: '3',
    );
    expect(parse('https://xddlabs.com/root/tbchat_packages/-/issues/3'), issue);
    expect(
      parse('https://xddlabs.com/root/tbchat_packages/-/issues/3/'),
      issue,
    );
    expect(
      parse('https://xddlabs.com/root/tbchat_packages/-/issues/3#note_1'),
      issue,
    );
  });

  test('GitHub issues', () {
    expect(parse('https://github.com/flutter/flutter/issues/12'), (
      provider: ProviderType.github,
      kind: LinkedItemKind.issue,
      host: 'github.com',
      project: 'flutter/flutter',
      number: '12',
    ));
    expect(
      parse('https://github.acme.com/team/app/issues/7')?.kind,
      LinkedItemKind.issue,
    );
  });

  test('same: GitLab tells issues from MRs, GitHub shares numbers', () {
    bool same(String a, String b) =>
        ParseMergeRequestLink.same(parse(a)!, parse(b)!);
    expect(
      same(
        'https://xddlabs.com/root/tbchat/-/issues/3',
        'https://xddlabs.com/Root/TBChat/-/issues/3#note_1',
      ),
      isTrue,
    );
    expect(
      same(
        'https://xddlabs.com/root/tbchat/-/issues/3',
        'https://xddlabs.com/root/tbchat/-/merge_requests/3',
      ),
      isFalse,
    );
    expect(
      same(
        'https://github.com/flutter/flutter/issues/12',
        'https://github.com/flutter/flutter/pull/12',
      ),
      isTrue,
    );
  });

  test('other links are not merge requests or issues', () {
    expect(parse('https://github.com/flutter/flutter/commits/main'), isNull);
    expect(parse('https://xddlabs.com/root/tbchat/-/milestones/9'), isNull);
    expect(parse('https://zentao.example/task-view-1.html'), isNull);
    // Other forges' (and GitLab's old) issue paths keep their web preview.
    expect(parse('https://bitbucket.org/acme/app/issues/12'), isNull);
    expect(parse('https://xddlabs.com/root/tbchat/issues/3'), isNull);
    expect(parse('not a link'), isNull);
  });
}

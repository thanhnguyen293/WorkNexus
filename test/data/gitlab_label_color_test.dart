import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_models.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_normalize.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';

void main() {
  // A merge request as returned by GitLab with `with_labels_details=true`:
  // `labels` is an array of objects carrying `color` + `text_color`.
  final mrJson = <String, dynamic>{
    'id': 111,
    'iid': 987,
    'project_id': 9,
    'title': 'Draft: fix',
    'state': 'opened',
    'draft': true,
    'labels': [
      {
        'id': 1,
        'name': 'do-not-merge',
        'color': '#dc143c',
        'text_color': '#FFFFFF',
      },
    ],
    'references': {'full': 'root/tbchat_socialfi!987'},
  };

  test('with_labels_details labels parse into name + color', () {
    final mr = GitLabMergeRequest.fromJson(mrJson);
    expect(mr.labelNames, ['do-not-merge']);
    expect(mr.labelColorMap, {'do-not-merge': '#dc143c'});
    expect(mr.labelTextColorMap, {'do-not-merge': '#FFFFFF'});
  });

  test('normalized ticket carries label colors on the GitLab entity', () {
    final ticket = normalizeGitLabMergeRequest(
      GitLabMergeRequest.fromJson(mrJson),
      accountId: 'acc',
    );
    final entity = ticket.providerEntity as GitLabItemEntity;
    expect(entity.labelColors, {'do-not-merge': '#dc143c'});
    expect(entity.labelTextColors, {'do-not-merge': '#FFFFFF'});
    expect(ticket.labels, ['do-not-merge']);
  });

  test('bare-string labels (no details) still parse, without colors', () {
    final mr = GitLabMergeRequest.fromJson({
      ...mrJson,
      'labels': ['do-not-merge'],
    });
    expect(mr.labelNames, ['do-not-merge']);
    expect(mr.labelColorMap, isEmpty);
  });
}

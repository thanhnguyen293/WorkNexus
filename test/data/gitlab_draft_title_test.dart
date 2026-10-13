import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_draft_title.dart';

void main() {
  test('readyTitle strips every prefix GitLab treats as draft', () {
    expect(readyTitle('Draft: Fix login'), 'Fix login');
    expect(readyTitle('[Draft] Fix login'), 'Fix login');
    expect(readyTitle('(draft) Fix login'), 'Fix login');
    expect(readyTitle('WIP: Fix login'), 'Fix login');
    expect(readyTitle('Draft: [WIP] Fix login'), 'Fix login');
  });

  test('readyTitle leaves a title that only mentions draft alone', () {
    expect(readyTitle('Fix draft autosave'), 'Fix draft autosave');
  });

  test('draftTitle adds the canonical prefix exactly once', () {
    expect(draftTitle('Fix login'), 'Draft: Fix login');
    expect(draftTitle('WIP: Fix login'), 'Draft: Fix login');
  });
}

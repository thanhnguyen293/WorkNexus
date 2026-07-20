import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/util/priority_labels.dart';

Ticket _ticket({
  required ProviderType provider,
  List<String> labels = const [],
}) => Ticket(
  id: 'x',
  accountId: 'a',
  projectId: 'p',
  providerType: provider,
  externalKey: '1',
  externalType: 'mergerequest',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'opened',
  sourceHash: 'h',
  labels: labels,
);

void main() {
  group('gitLabPriorityFromLabels', () {
    test('reads a priority:: scoped label', () {
      expect(gitLabPriorityFromLabels(['priority::1']), Priority.urgent);
      expect(gitLabPriorityFromLabels(['priority::2']), Priority.high);
      expect(gitLabPriorityFromLabels(['priority::3']), Priority.medium);
      expect(gitLabPriorityFromLabels(['priority::critical']), Priority.urgent);
    });

    test('is null when no priority label is present', () {
      expect(gitLabPriorityFromLabels(['bug', 'discover']), isNull);
      expect(gitLabPriorityFromLabels(const []), isNull);
    });
  });

  group('gitHubPriorityFromLabels', () {
    test('reads P-style and "priority:" labels', () {
      expect(gitHubPriorityFromLabels(['P0']), Priority.urgent);
      expect(gitHubPriorityFromLabels(['priority: high']), Priority.high);
      expect(gitHubPriorityFromLabels(['priority/3']), Priority.medium);
    });

    test('is null when no priority label is present', () {
      expect(gitHubPriorityFromLabels(['bug', 'enhancement']), isNull);
      expect(gitHubPriorityFromLabels(const []), isNull);
    });
  });

  group('hasExplicitPriority', () {
    test('GitLab/GitHub: only when a real priority label is present', () {
      expect(
        hasExplicitPriority(_ticket(provider: ProviderType.gitlab)),
        isFalse,
      );
      expect(
        hasExplicitPriority(
          _ticket(provider: ProviderType.gitlab, labels: ['priority::2']),
        ),
        isTrue,
      );
      expect(
        hasExplicitPriority(_ticket(provider: ProviderType.github)),
        isFalse,
      );
      expect(
        hasExplicitPriority(
          _ticket(provider: ProviderType.github, labels: ['P1']),
        ),
        isTrue,
      );
    });

    test('ZenTao always has a native priority', () {
      expect(
        hasExplicitPriority(_ticket(provider: ProviderType.zentao)),
        isTrue,
      );
    });
  });
}

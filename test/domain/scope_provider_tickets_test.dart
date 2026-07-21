import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/usecases/scope_provider_tickets.dart';

Ticket _t({
  required String id,
  String accountId = 'gl',
  ProviderType providerType = ProviderType.gitlab,
  String externalType = 'MergeRequest',
  List<String> labels = const [],
}) => Ticket(
  id: id,
  accountId: accountId,
  projectId: 'p',
  providerType: providerType,
  externalKey: id,
  externalType: externalType,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'opened',
  sourceHash: 'h',
  labels: labels,
);

void main() {
  const scope = ScopeProviderTickets();
  const projectLabel = 'gitlab-project:42';

  final all = [
    _t(id: 'a', labels: const [projectLabel]),
    _t(id: 'b', labels: const [projectLabel]),
    _t(id: 'c', labels: const []), // right account/type, no membership label
    _t(id: 'd', accountId: 'other', labels: const [projectLabel]),
    _t(id: 'e', externalType: 'Issue', labels: const [projectLabel]),
    _t(
      id: 'f',
      providerType: ProviderType.github,
      labels: const [projectLabel],
    ),
  ];

  List<String> ids(List<Ticket> t) => [for (final x in t) x.id];

  test('offline (slice == null) renders every cached member of the scope', () {
    final result = scope(
      tickets: all,
      accountId: 'gl',
      providerType: ProviderType.gitlab,
      externalType: 'MergeRequest',
      membershipLabel: projectLabel,
      slice: null,
    );
    // a + b match; c lacks the label, d wrong account, e wrong type, f wrong
    // provider.
    expect(ids(result), ['a', 'b']);
  });

  test(
    'online (slice present) reconciles — prunes members not in the slice',
    () {
      final result = scope(
        tickets: all,
        accountId: 'gl',
        providerType: ProviderType.gitlab,
        externalType: 'MergeRequest',
        membershipLabel: projectLabel,
        slice: const {'a'}, // server no longer lists b
      );
      expect(ids(result), ['a']);
    },
  );

  test('a slice id that is not a scope member is still excluded', () {
    final result = scope(
      tickets: all,
      accountId: 'gl',
      providerType: ProviderType.gitlab,
      externalType: 'MergeRequest',
      membershipLabel: projectLabel,
      slice: const {'a', 'c', 'd'}, // c has no label, d wrong account
    );
    expect(ids(result), ['a']);
  });

  test('externalType match is case-insensitive', () {
    final tickets = [_t(id: 'x', externalType: 'mergerequest')];
    final result = scope(
      tickets: tickets,
      accountId: 'gl',
      providerType: ProviderType.gitlab,
      externalType: 'MergeRequest',
      slice: null,
    );
    expect(ids(result), ['x']);
  });

  test('no membershipLabel → account + type + provider decide membership', () {
    final result = scope(
      tickets: all,
      accountId: 'gl',
      providerType: ProviderType.gitlab,
      externalType: 'MergeRequest',
      slice: null,
    );
    // a, b, c all qualify (label not required); d/e/f still excluded.
    expect(ids(result), ['a', 'b', 'c']);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/detail_header_title.dart';

Ticket _ticket(ProviderType provider, String key) => Ticket(
  id: 'x:$key',
  accountId: 'x',
  projectId: 'x:P',
  providerType: provider,
  externalKey: key,
  externalType: 'Bug',
  title: 'Filter is missing',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
);

void main() {
  test('the shared title leads with the ticket id', () {
    expect(
      ticketTitleWithRef(_ticket(ProviderType.zentao, '6534')),
      '#6534 Filter is missing',
    );
    // A Jira key is already a reference; no `#` in front of it.
    expect(
      ticketTitleWithRef(_ticket(ProviderType.jira, 'APP-12')),
      'APP-12 Filter is missing',
    );
  });

  testWidgets('the header title shows the id and can be selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: DetailHeaderTitle(ticket: _ticket(ProviderType.zentao, '6534')),
        ),
      ),
    );

    final title = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(title.textSpan?.toPlainText(), '#6534 Filter is missing');
  });
}

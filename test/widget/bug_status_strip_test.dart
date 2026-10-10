import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/bug_status_strip.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String status,
    required UnifiedStatus unified,
    required ZenTaoBugEntity bug,
  }) async {
    final ticket = Ticket(
      id: 'zt:1',
      accountId: 'zt',
      projectId: 'zt:P',
      providerType: ProviderType.zentao,
      externalKey: '1',
      title: 't',
      body: 'b',
      priority: Priority.medium,
      status: unified,
      providerStatus: status,
      sourceHash: 'h',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: BugStatusStrip(ticket: ticket, bug: bug),
        ),
      ),
    );
  }

  testWidgets('a resolved bug folds its resolution into the status chip', (
    tester,
  ) async {
    await pump(
      tester,
      status: 'resolved',
      unified: UnifiedStatus.review,
      bug: const ZenTaoBugEntity(confirmed: 1, resolution: 'fixed'),
    );
    expect(find.text('Resolved · Fixed'), findsOneWidget);
    expect(find.text('Fixed'), findsNothing);
    // Confirmation is history once the bug is resolved.
    expect(find.text('Confirmed'), findsNothing);
  });

  testWidgets('an open bug shows whether it was confirmed', (tester) async {
    await pump(
      tester,
      status: 'active',
      unified: UnifiedStatus.todo,
      bug: const ZenTaoBugEntity(confirmed: 1, activatedCount: 2),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Reopened ×2'), findsOneWidget);
  });
}

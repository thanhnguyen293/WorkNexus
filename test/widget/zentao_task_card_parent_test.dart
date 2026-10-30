import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/translation_state.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_card_parent.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_task_card.dart';

const _task = Ticket(
  id: 'acc1:task:13600',
  accountId: 'acc1',
  projectId: 'p1',
  providerType: ProviderType.zentao,
  externalKey: '13600',
  externalType: 'Task',
  title: 'dev cloud',
  body: '',
  priority: Priority.low,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'hash',
  assignee: 'Tran',
);

void main() {
  Widget harness(Ticket ticket, {List<Ticket> synced = const []}) =>
      ProviderScope(
        overrides: [
          ticketsProvider.overrideWith((ref) => Stream.value(synced)),
          lookupsProvider.overrideWithValue((
            accounts: const {},
            workspaces: const {},
            projects: const {},
          )),
          initialAppSettingsProvider.overrideWithValue(const AppSettings()),
          openTicketIdProvider.overrideWithValue(null),
          translationStatusProvider(
            ticket.id,
          ).overrideWithValue((state: TranslationState.none, record: null)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 256, child: ZenTaoTaskCard(ticket)),
            ),
          ),
        ),
      );

  testWidgets('a subtask card shows its parent task number and title', (
    tester,
  ) async {
    final subtask = _task.copyWith(
      providerEntity: const TicketProviderEntity.zentaoTask(
        parentId: '12964',
        parentName: 'Save assets from a cloud drive',
      ),
    );
    await tester.pumpWidget(harness(subtask));
    await tester.pumpAndSettle();

    expect(find.text('#12964'), findsOneWidget);
    expect(find.text('Save assets from a cloud drive'), findsOneWidget);
  });

  testWidgets('without a parent name it shows the synced parent title', (
    tester,
  ) async {
    final subtask = _task.copyWith(
      providerEntity: const TicketProviderEntity.zentaoTask(parentId: '12964'),
    );
    final parent = _task.copyWith(
      id: 'acc1:task:12964',
      title: 'Synced parent title',
    );
    await tester.pumpWidget(harness(subtask, synced: [parent]));
    await tester.pumpAndSettle();

    expect(find.text('#12964'), findsOneWidget);
    expect(find.text('Synced parent title'), findsOneWidget);
  });

  testWidgets('a task without a parent shows no parent line', (tester) async {
    await tester.pumpWidget(
      harness(
        _task.copyWith(providerEntity: const TicketProviderEntity.zentaoTask()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ZenTaoCardParent), findsNothing);
  });
}

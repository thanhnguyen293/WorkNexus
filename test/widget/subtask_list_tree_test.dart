import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_ticket_id.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/detail/subtask_list.dart';

final _parent = Ticket(
  id: zenTaoTicketId('zt', 'task', '14429'),
  accountId: 'zt',
  projectId: 'zt:task',
  providerType: ProviderType.zentao,
  externalKey: '14429',
  externalType: 'Task',
  title: 'Multi-sign',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: '',
  url: 'https://zentao.example.com/zentao/task-view-14429.html',
);

TicketSubtask _sub(String id, String title, String parent) => TicketSubtask(
  id: id,
  title: title,
  status: UnifiedStatus.todo,
  parentId: parent,
);

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
            body: SubtaskList(
              ticket: _parent,
              // ZenTao lists every level flat, grandchildren among children.
              subtasks: [
                _sub('14520', 'Flow 1 · Create account', '14429'),
                _sub('14521', 'Flow 3 · Member signing', '14429'),
                _sub('14528', 'Flow 1 · Wallet UI', '14520'),
                _sub('14529', 'Flow 1 · Wallet SDK', '14520'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a grandchild stays hidden until its parent is expanded', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('SUBTASKS (2 · 4 TOTAL)'), findsOneWidget);
    expect(find.text('Flow 1 · Create account'), findsOneWidget);
    expect(find.text('Flow 3 · Member signing'), findsOneWidget);
    expect(find.text('Flow 1 · Wallet UI'), findsNothing);

    // Only the subtask with subtasks of its own gets a chevron.
    expect(find.byTooltip('Show subtasks'), findsOneWidget);
    await tester.tap(find.byTooltip('Show subtasks'));
    await tester.pumpAndSettle();

    expect(find.text('Flow 1 · Wallet UI'), findsOneWidget);
    expect(find.text('Flow 1 · Wallet SDK'), findsOneWidget);
    // Nested under its parent: indented past the direct subtasks' ids.
    expect(
      tester.getTopLeft(find.text('#14528')).dx,
      greaterThan(tester.getTopLeft(find.text('#14520')).dx),
    );

    await tester.tap(find.byTooltip('Hide subtasks'));
    await tester.pumpAndSettle();
    expect(find.text('Flow 1 · Wallet UI'), findsNothing);
  });
}

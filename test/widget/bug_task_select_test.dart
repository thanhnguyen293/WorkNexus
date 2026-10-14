import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/zentao_ticket_form.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/ticket_editor/presentation/widgets/bug_task_select.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// A bug's Task field asks for the execution first, since ZenTao lists tasks
/// per execution.
void main() {
  const options = BugFormOptions(
    executions: [FormOption(value: '31', label: 'Sprint 12')],
    tasks: [FormOption(value: '10007', label: '#10007 Share sheet')],
  );

  Future<(List<String>, List<String>)> pump(
    WidgetTester tester, {
    required String execution,
  }) async {
    final executions = <String>[];
    final tasks = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: BugTaskSelect(
                options: options,
                execution: execution,
                task: '0',
                onExecution: executions.add,
                onTask: tasks.add,
              ),
            ),
          ),
        ),
      ),
    );
    return (executions, tasks);
  }

  testWidgets('without an execution it lists executions to pick', (
    tester,
  ) async {
    final (executions, tasks) = await pump(tester, execution: '0');

    await tester.tap(find.text('Pick an execution first'));
    await tester.pumpAndSettle();
    expect(find.text('#10007 Share sheet'), findsNothing);
    await tester.tap(find.text('Sprint 12'));
    await tester.pumpAndSettle();

    expect(executions, ['31']);
    expect(tasks, isEmpty);
  });

  testWidgets('with an execution it lists its tasks', (tester) async {
    final (executions, tasks) = await pump(tester, execution: '31');

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#10007 Share sheet'));
    await tester.pumpAndSettle();

    expect(tasks, ['10007']);
    expect(executions, isEmpty);
  });
}

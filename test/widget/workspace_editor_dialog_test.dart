import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/presentation/widgets/workspace_editor_dialog.dart';

void main() {
  testWidgets('workspace editor uses file picker instead of preset icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(
          body: WorkspaceEditorDialog(
            workspace: Workspace(
              id: 'workspace',
              name: 'Nexsoft',
              shortCode: 'N',
              colorValue: 0xFF16A99C,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Workspace style'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('No file selected'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.apartment), findsNothing);
    expect(find.byIcon(Icons.rocket_launch_outlined), findsNothing);
  });
}

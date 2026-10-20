import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/workspace_badge.dart';
import 'package:work_nexus/features/connections/presentation/widgets/workspace_editor_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _nexsoft = Workspace(
  id: 'workspace',
  name: 'Nexsoft',
  shortCode: 'N',
  colorValue: 0xFF16A99C,
);

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  home: home,
);

/// Opens the editor over a page and gives back what it was closed with.
Future<Future<Workspace?> Function()> _open(
  WidgetTester tester,
  Workspace ws,
) async {
  Workspace? result;
  var closed = false;
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<Workspace>(
                context: context,
                builder: (_) => WorkspaceEditorDialog(workspace: ws),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  return () async {
    await tester.pumpAndSettle();
    return closed ? result : null;
  };
}

void main() {
  testWidgets('workspace editor uses file picker instead of preset icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: WorkspaceEditorDialog(workspace: _nexsoft))),
    );

    expect(find.text('Edit workspace'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('No file selected'), findsOneWidget);
    expect(find.byIcon(LucideIcons.house300), findsNothing);
    expect(find.byIcon(LucideIcons.building2300), findsNothing);
    expect(find.byIcon(LucideIcons.rocket300), findsNothing);
  });

  testWidgets('renaming saves the new name and its badge letters', (
    tester,
  ) async {
    final result = await _open(tester, _nexsoft);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nexsoft'),
      'Globex Corp',
    );
    await tester.enterText(find.widgetWithText(TextField, 'N'), '');
    await tester.pump();
    await tester.tap(find.text('Save'));
    final saved = await result();

    expect(saved?.name, 'Globex Corp');
    expect(saved?.shortCode, 'GC');
    expect(saved?.id, 'workspace');
  });

  testWidgets('both badges show the letters being typed', (tester) async {
    await _open(tester, _nexsoft);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'N'), 'gx');
    await tester.pump();

    final shown = tester
        .widgetList<WorkspaceBadge>(find.byType(WorkspaceBadge))
        .map((badge) => badge.short);
    expect(shown, ['GX', 'GX']);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: WorkspaceEditorDialog(workspace: _nexsoft))),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Nexsoft'), '  ');
    await tester.pump();

    expect(find.text('Enter a name'), findsOneWidget);
    final save = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Save'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('the personal workspace has no name to edit', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: WorkspaceEditorDialog(
            workspace: _nexsoft.copyWith(isPersonal: true, name: 'Personal'),
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextField, 'Personal'), findsNothing);
    expect(find.text('Personal'), findsOneWidget);
  });
}

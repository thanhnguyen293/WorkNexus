import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/repositories/workspace_repository.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/presentation/widgets/create_workspace_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockWorkspaces extends Mock implements WorkspaceRepository {}

const _workspace = Workspace(id: 'w', name: 'w', shortCode: 'W', colorValue: 0);

void main() {
  late _MockWorkspaces workspaces;

  setUpAll(() => registerFallbackValue(_workspace));

  setUp(() async {
    await getIt.reset();
    workspaces = _MockWorkspaces();
    getIt.registerSingleton<WorkspaceRepository>(workspaces);
  });

  tearDown(getIt.reset);

  testWidgets('a workspace that cannot be created says why', (tester) async {
    when(
      () => workspaces.createWorkspace(any()),
    ).thenThrow(Exception('disk full'));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CreateWorkspaceDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Team Alpha');
    await tester.tap(find.text('Create & Join'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Couldn't create the workspace"),
      findsOneWidget,
    );
    // The dialog stays, ready to try again.
    expect(find.text('Create & Join'), findsOneWidget);
  });
}

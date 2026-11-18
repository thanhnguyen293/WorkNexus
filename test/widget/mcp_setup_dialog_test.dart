import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/mcp_setup.dart';
import 'package:work_nexus/features/chat/presentation/providers/mcp_setup_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/mcp_setup_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, McpSetup setup) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mcpSetupProvider.overrideWith((ref) async => setup)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(body: McpSetupDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Claude Code command with the real paths', (
    tester,
  ) async {
    await pump(
      tester,
      const McpSetup(
        scriptPath: '/support/mcp/worknexus-mcp.mjs',
        nodePath: '/usr/local/bin/node',
        nodeVersion: 'v22.13.0',
      ),
    );
    expect(find.text('Claude Code'), findsOneWidget);
    expect(
      find.textContaining(
        'claude mcp add worknexus -s user -- "/usr/local/bin/node" '
        '"/support/mcp/worknexus-mcp.mjs"',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Node.js v22.13.0 at /usr/local/bin/node'),
      findsOneWidget,
    );
    expect(find.text('Get Node.js'), findsNothing);
    expect(find.textContaining('version manager'), findsNothing);
  });

  testWidgets('warns when Node.js comes from a version manager', (
    tester,
  ) async {
    await pump(
      tester,
      const McpSetup(
        scriptPath: '/s.mjs',
        nodePath: '/Users/me/.nvm/versions/node/v22.14.0/bin/node',
        nodeVersion: 'v22.14.0',
      ),
    );
    expect(find.textContaining('version manager'), findsOneWidget);
  });

  testWidgets('offers to get Node.js when none is found', (tester) async {
    await pump(tester, const McpSetup(scriptPath: '/s.mjs'));
    expect(find.textContaining('Node.js was not found'), findsOneWidget);
    expect(find.text('Get Node.js'), findsOneWidget);
  });
}

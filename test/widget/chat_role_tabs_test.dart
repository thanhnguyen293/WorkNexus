import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_role_tabs.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<String?> roles,
    ValueChanged<String?> onSelect, {
    Map<String, String> serverNames = const {},
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(
        body: ChatRoleTabs(
          roles: roles,
          selected: null,
          onSelect: onSelect,
          serverNames: serverNames,
        ),
      ),
    ),
  );

  testWidgets('a tab per role, most senior first, with counts', (tester) async {
    String? picked = 'unset';
    await pump(tester, ['dev', 'top', 'dev', null], (r) => picked = r);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Senior Manager'), findsOneWidget);
    expect(find.text('Developẻ'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('No role'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Senior Manager')).dx,
      lessThan(tester.getTopLeft(find.text('Developẻ')).dx),
    );

    await tester.tap(find.text('Developẻ'));
    expect(picked, 'dev');
    expect(chatRoleMatches('dev', ' dev'), isTrue);
    expect(chatRoleMatches('', null), isTrue);
  });

  testWidgets('no tabs when everyone shares one role', (tester) async {
    await pump(tester, ['dev', 'dev'], (_) {});
    expect(find.textContaining('All'), findsNothing);
  });

  testWidgets('roles an admin added: ours, then the server name, then code', (
    tester,
  ) async {
    await pump(
      tester,
      ['ui', 'dev', 'qc', 'zz'],
      (_) {},
      serverNames: {
        'qc': 'Quality Control',
        // Ours wins for the built-in roles.
        'dev': '研发',
      },
    );
    expect(find.text('Designer'), findsOneWidget);
    expect(find.text('Developẻ'), findsOneWidget);
    expect(find.text('Quality Control'), findsOneWidget);
    // Not named anywhere: the code itself.
    expect(find.text('zz'), findsOneWidget);
  });
}

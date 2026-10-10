import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/person_chip.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/board/presentation/widgets/ticket_card_meta.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, AssigneeChip chip) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personAvatarBuilderProvider.overrideWithValue(
            (context, {required accountId, required name, required diameter}) =>
                Text('photo:$accountId:$name'),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: chip),
        ),
      ),
    );
  }

  testWidgets('a ZenTao assignee shows their chat photo', (tester) async {
    await pump(
      tester,
      const AssigneeChip('Ryan', Colors.teal, accountId: 'zt'),
    );
    expect(find.text('photo:zt:Ryan'), findsOneWidget);
    expect(find.text('Ryan'), findsOneWidget);
  });

  testWidgets('without an account the assignee keeps an initial', (
    tester,
  ) async {
    await pump(tester, const AssigneeChip('Ryan', Colors.teal));
    expect(find.textContaining('photo:'), findsNothing);
    expect(find.text('R'), findsOneWidget);
  });
}

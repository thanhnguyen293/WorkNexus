import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/person_chip.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/domain/entities/zentao_doc_person.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_doc_people.dart';

void main() {
  testWidgets('a tap opens the people card, each with a message button', (
    tester,
  ) async {
    final asked = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personChatButtonBuilderProvider.overrideWithValue((
            context, {
            required accountId,
            required name,
          }) {
            asked.add(name);
            return Text('message $name');
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: ZenTaoDocPeople(
              accountId: 'a1',
              people: [
                ZenTaoDocPerson(account: 'Tompham', name: 'ViPham'),
                ZenTaoDocPerson(account: 'Tommy'),
              ],
              action: 'edited',
              title: 'Edited by',
            ),
          ),
        ),
      ),
    );

    expect(find.text('edited'), findsOneWidget);
    expect(find.text('Edited by'), findsNothing);

    await tester.tap(find.text('edited'));
    await tester.pumpAndSettle();

    expect(find.text('Edited by'), findsOneWidget);
    expect(find.text('ViPham'), findsOneWidget);
    expect(find.text('message Tompham'), findsOneWidget);
    expect(find.text('message Tommy'), findsOneWidget);
  });
}

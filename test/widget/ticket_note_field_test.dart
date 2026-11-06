import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/ticket_note_field.dart';

Ticket _ticket(ProviderType type) => Ticket(
  id: 't',
  accountId: 'a',
  projectId: 'p',
  providerType: type,
  externalKey: '1',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Ticket ticket,
    TicketNoteController c,
  ) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: const [
          ...AppL10n.localizationsDelegates,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: TicketNoteField(ticket: ticket, controller: c),
        ),
      ),
    ),
  );

  testWidgets('a ZenTao note is a rich editor sending HTML', (tester) async {
    final ticket = _ticket(ProviderType.zentao);
    final c = TicketNoteController(ticket);
    addTearDown(c.dispose);
    await pump(tester, ticket, c);

    expect(find.byType(RichTextEditor), findsOneWidget);
    expect(c.value, isEmpty);
    c.html.quill.document.insert(0, 'Fixed in build 396');
    expect(c.value, contains('<p>Fixed in build 396</p>'));
  });

  testWidgets('another provider keeps a plain text note', (tester) async {
    final ticket = _ticket(ProviderType.github);
    final c = TicketNoteController(ticket);
    addTearDown(c.dispose);
    await pump(tester, ticket, c);

    expect(find.byType(RichTextEditor), findsNothing);
    await tester.enterText(find.byType(TextField), 'LGTM');
    expect(c.value, 'LGTM');
  });
}
